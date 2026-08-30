package org.annoya.vpn_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.system.Os
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import mobile.Mobile
import mobile.SocketProtector

/// The Android tunnel: VpnService owns the tun fd and routing, the mihomo
/// engine (gomobile AAR) reads the fd — the same split as the Apple Network
/// Extension, including the process boundary.
///
/// It runs in `:tunnel`, and that separation is load-bearing rather than
/// tidiness. The engine is native code: a fault in it aborts its process. In
/// one process that took the UI down with it, and the app that was supposed to
/// report the failure was dead too — the app is built on the opposite
/// assumption, that a tunnel can die on its own and be explained afterwards
/// (ADR-004). It also means Android may reclaim the UI process without
/// touching a tunnel the user asked to stay up.
///
/// Two ways in, and only one path: the app starts it over the control channel
/// with a config it just wrote to disk; the system starts it directly —
/// always-on at boot, or a restart after a kill — with no app anywhere in
/// sight. Both read the same persisted config, which is why starting takes no
/// arguments: a start that needed the app alive would make always-on a lie.
class MihomoVpnService : VpnService() {

    companion object {
        const val ACTION_START = "org.annoya.vpn_client.START"
        const val ACTION_STOP = "org.annoya.vpn_client.STOP"
    }

    /// Engine calls run off the caller's thread, one at a time: start, reload
    /// and stop all touch shared engine state, and neither a binder thread nor
    /// the one delivering onStartCommand may block on a config parse.
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    /// The tun fd as a bare number, not a ParcelFileDescriptor: ownership is
    /// handed to the engine the moment it starts. sing-tun wraps the fd
    /// directly (no dup) and closes it on Stop — keeping a PFD around meant a
    /// second close() on the same number, which Android's fdsan answers with
    /// SIGABRT, not a log line. detachFd() unregisters our claim; from then on
    /// the engine is the one owner and this is only a number to reload with.
    @Volatile private var tunFd: Int? = null
    private var logStream: FileOutputStream? = null

    private val binder = object : ITunnel.Stub() {
        override fun stop() = shutdown()

        override fun reload(config: String): String {
            val fd = tunFd ?: return "tunnel is not running"
            return try {
                executor.submit<String> {
                    try {
                        Mobile.reload(fd.toLong(), config)
                        log("hot reload applied")
                        ""
                    } catch (e: Exception) {
                        log("hot reload failed: ${e.message}")
                        e.message ?: "reload failed"
                    }
                }.get()
            } catch (e: Exception) {
                e.message ?: "reload failed"
            }
        }

        override fun status(): String = TunnelState.status
        override fun connectedSince(): Double = TunnelState.connectedSince

        override fun groupMember(group: String): String =
            if (TunnelState.status == TunnelState.CONNECTED) {
                runCatching { Mobile.groupMember(group) }.getOrDefault("")
            } else ""

        override fun isAlwaysOn(): Boolean =
            Build.VERSION.SDK_INT >= 29 && this@MihomoVpnService.isAlwaysOn

        override fun setLogging(enabled: Boolean) {
            TunnelFiles.setLogsEnabled(this@MihomoVpnService, enabled)
            runCatching { Mobile.setLogLevel(if (enabled) "info" else "silent") }
        }

        override fun registerCallback(cb: ITunnelCallback) = TunnelState.register(cb)
        override fun unregisterCallback(cb: ITunnelCallback) = TunnelState.unregister(cb)
    }

    /// The system's own bind (action `android.net.VpnService`) must get the
    /// default VpnService binder, or always-on breaks; ours is for the app.
    override fun onBind(intent: Intent?): IBinder? =
        if (intent?.action == SERVICE_INTERFACE) super.onBind(intent) else binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A null intent is the system restarting us after a kill; the
        // SERVICE_INTERFACE action is always-on. Both mean "bring it up".
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        if (tunFd != null) return START_STICKY // already up; nothing to do
        startForeground(1, buildNotification())
        TunnelState.set(TunnelState.CONNECTING)
        executor.execute { bringUp() }
        return START_STICKY
    }

    private fun bringUp() {
        try {
            val config = TunnelFiles.config(this).takeIf { it.exists() }?.readText()
                ?: throw IllegalStateException("no saved tunnel config to start from")

            // Mirrors the Apple extension's NEPacketTunnelNetworkSettings: the
            // tunnel owns both families end to end, nothing is excluded — the
            // engine's own dials bypass the routes via protect(), not via a
            // route hole, so a failed protect goes silent instead of leaking.
            val builder = Builder()
                .setSession("VPN")
                .setMtu(9000)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addAddress("fdfe:dcba:9876::1", 126)
                .addRoute("::", 0)
                // A decoy, like NEDNSSettings on Apple: the address only has
                // to be routed into the tun, where dns-hijack any:53 answers.
                .addDnsServer("1.1.1.1")
            val pfd = builder.establish()
                ?: throw IllegalStateException("the system refused to establish the tunnel")
            val fd = pfd.detachFd()
            tunFd = fd

            Mobile.setSocketProtector(object : SocketProtector {
                override fun protect(sock: Long): Boolean =
                    this@MihomoVpnService.protect(sock.toInt())
            })
            Mobile.setHomeDir(TunnelFiles.engineDir(this).absolutePath)
            redirectEngineOutput()
            Mobile.setLogLevel(if (TunnelFiles.logsEnabled(this)) "info" else "silent")
            log("starting engine on fd $fd")
            Mobile.start(fd.toLong(), config)
            TunnelFiles.clearError(this)
            TunnelState.set(TunnelState.CONNECTED)
            log("tunnel up")
        } catch (e: Exception) {
            log("start failed: ${e.message}")
            TunnelFiles.recordError(this, e.message ?: "start failed")
            TunnelState.set(TunnelState.ERROR)
            shutdown()
        }
    }

    fun shutdown() {
        executor.execute {
            // Stop closes the fd too — the engine owns it (see tunFd).
            runCatching { Mobile.stop() }
            tunFd = null
            TunnelState.set(TunnelState.DISCONNECTED)
            log("tunnel down")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /// The user enabled another VPN, or pulled the plug in system settings.
    /// The system already unrouted us; all that is left is honesty.
    override fun onRevoke() {
        log("revoked by the system")
        TunnelFiles.recordError(this,
            "the system revoked the VPN (another VPN app, or turned off in settings)")
        shutdown()
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    /// mihomo logs to stdout; point fds 1/2 at a file in the engine dir so
    /// `fetch_log` has something to read — same trick as the Apple extension,
    /// which cannot be skipped here either: logcat is not exportable by us.
    private fun redirectEngineOutput() {
        if (logStream != null) return
        try {
            val out = FileOutputStream(TunnelFiles.engineLog(this), true)
            Os.dup2(out.fd, 1)
            Os.dup2(out.fd, 2)
            logStream = out // held so the fd stays open
        } catch (e: Exception) {
            log("stdout redirect failed: ${e.message}")
        }
    }

    private fun log(line: String) {
        if (!TunnelFiles.logsEnabled(this)) return
        runCatching {
            TunnelFiles.serviceLog(this).appendText("${java.time.LocalDateTime.now()} $line\n")
        }
    }

    /// The persistent notification a foreground VpnService must carry. Silent
    /// and minimal: the OS already shows its own key icon for an active VPN.
    private fun buildNotification(): Notification {
        val channelId = "vpn"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(channelId, "VPN", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("VPN")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }
}
