package org.annoya.vpn_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.Os
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import mobile.Mobile
import mobile.SocketProtector

/// The Android tunnel: VpnService owns the tun fd and routing, the mihomo
/// engine (gomobile AAR, in-process) reads the fd — the same split as the
/// Apple Network Extension, minus the process boundary.
///
/// Two ways in. The app starts it over the control channel with a config it
/// just wrote to disk; the system starts it directly — always-on at boot, or a
/// restart after a kill — with no Flutter engine anywhere in sight. Both paths
/// read the same persisted config, which is why `start` takes no arguments:
/// a start that needed the app to be alive would make always-on a lie.
class MihomoVpnService : VpnService() {

    companion object {
        const val ACTION_START = "org.annoya.vpn_client.START"
        const val ACTION_STOP = "org.annoya.vpn_client.STOP"

        /// The running service, reachable because the service shares the app's
        /// process. Null when the tunnel is down.
        @Volatile var instance: MihomoVpnService? = null
            private set

        /// The engine's working directory: rendered config, geo databases,
        /// logs. The Dart side gets this via `shared_dir` and downloads geo
        /// data into it, exactly as it does with the App Group container.
        fun engineDir(context: Context): File =
            File(context.filesDir, "engine").apply { mkdirs() }

        fun configFile(context: Context): File = File(engineDir(context), "last_config.yaml")
        fun engineLogFile(context: Context): File = File(engineDir(context), "mihomo.log")
        fun serviceLogFile(context: Context): File = File(engineDir(context), "tunnel.log")
    }

    /// Engine calls run off the main thread, one at a time: Start/Reload/Stop
    /// touch shared engine state, and the binder thread that delivers
    /// onStartCommand must not block on a config parse.
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    /// The tun fd as a bare number, not a ParcelFileDescriptor: ownership is
    /// handed to the engine the moment it starts. sing-tun wraps the fd
    /// directly (no dup) and closes it on Stop — keeping a PFD around meant a
    /// second close() on the same number, which Android's fdsan answers with
    /// SIGABRT, not a log line. detachFd() unregisters our claim; from then on
    /// the engine is the one owner and this field is only a number to reload
    /// with.
    private var tunFd: Int? = null
    private var logStream: FileOutputStream? = null

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
            val config = configFile(this).takeIf { it.exists() }?.readText()
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
                override fun protect(sock: Long): Boolean = this@MihomoVpnService.protect(sock.toInt())
            })
            Mobile.setHomeDir(engineDir(this).absolutePath)
            redirectEngineOutput()
            Mobile.setLogLevel(if (logsEnabled()) "info" else "silent")
            log("starting engine on fd $fd")
            Mobile.start(fd.toLong(), config)
            TunnelState.clearError(this)
            TunnelState.set(TunnelState.CONNECTED)
            log("tunnel up")
        } catch (e: Exception) {
            log("start failed: ${e.message}")
            TunnelState.recordError(this, e.message ?: "start failed")
            TunnelState.set(TunnelState.ERROR)
            shutdown()
        }
    }

    /// Hot switch: new config, same fd, session survives — the engine keeps
    /// the tun listener when the tun section is unchanged, which ours is by
    /// design. Throws back to the channel on failure, with the engine still
    /// running on the previous config.
    fun reload(config: String, done: (Exception?) -> Unit) {
        executor.execute {
            val fd = tunFd
            if (fd == null) {
                done(IllegalStateException("tunnel is not running"))
                return@execute
            }
            try {
                Mobile.reload(fd.toLong(), config)
                log("hot reload applied")
                done(null)
            } catch (e: Exception) {
                log("hot reload failed: ${e.message}")
                done(e)
            }
        }
    }

    fun shutdown() {
        executor.execute {
            // Stop closes the fd too — the engine owns it (see tunFd).
            try { Mobile.stop() } catch (_: Exception) {}
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
        TunnelState.recordError(this, "the system revoked the VPN (another VPN app, or turned off in settings)")
        shutdown()
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        executor.shutdown()
        super.onDestroy()
    }

    /// mihomo logs to stdout; point fds 1/2 at a file in the engine dir so
    /// `fetch_log` has something to read — same trick as the Apple extension,
    /// which cannot be skipped here either: logcat is not exportable by us.
    private fun redirectEngineOutput() {
        if (logStream != null) return
        try {
            val out = FileOutputStream(engineLogFile(this), true)
            Os.dup2(out.fd, 1)
            Os.dup2(out.fd, 2)
            logStream = out // held so the fd stays open
        } catch (e: Exception) {
            log("stdout redirect failed: ${e.message}")
        }
    }

    private fun logsEnabled(): Boolean =
        getSharedPreferences("vpn_state", Context.MODE_PRIVATE).getBoolean("log_enabled", true)

    private fun log(line: String) {
        if (!logsEnabled()) return
        try {
            serviceLogFile(this).appendText(
                "${java.time.LocalDateTime.now()} $line\n")
        } catch (_: Exception) {}
    }

    /// The persistent notification a foreground VpnService must carry. Silent
    /// and minimal: the OS already shows its own key icon for an active VPN.
    private fun buildNotification(): Notification {
        val channelId = "vpn"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(channelId, "VPN", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("VPN")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }
}
