package org.anoya.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.IBinder
import android.system.Os
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import mobile.Mobile
import mobile.SocketProtector

class MihomoVpnService : VpnService() {

    companion object {
        const val ACTION_START = "org.anoya.vpn.START"
        const val ACTION_STOP = "org.anoya.vpn.STOP"

        const val kTunnelOutbound = "PROXY"
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    // Not a PFD: its second close() of the engine-owned fd is a SIGABRT under fdsan.
    @Volatile private var tunFd: Int? = null
    private var logStream: FileOutputStream? = null

    private val binder = object : ITunnel.Stub() {
        override fun stop() = shutdown()

        override fun reload(config: String): String {
            return try {
                executor.submit<String> {
                    val fd = tunFd ?: return@submit "tunnel is not running"
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

        override fun connectedSince(): Double = TunnelState.connectedSince

        override fun groupMember(group: String): String =
            if (TunnelState.status == TunnelState.CONNECTED) {
                runCatching { Mobile.groupMember(group) }.getOrDefault("")
            } else ""

        override fun urlTest(url: String, timeoutMs: Int): String =
            if (TunnelState.status == TunnelState.CONNECTED) {
                runCatching { "ms:" + Mobile.urlTest(kTunnelOutbound, url, timeoutMs.toLong()) }
                    .getOrElse { "err:" + (it.message ?: "the engine did not answer") }
            } else "err:the tunnel is not running"

        override fun proxyBytes(): String =
            if (TunnelState.status == TunnelState.CONNECTED) {
                runCatching { Mobile.proxyBytes(kTunnelOutbound) }.getOrDefault("0:0")
            } else "0:0"

        override fun setLogging(enabled: Boolean) {
            TunnelFiles.setLogsEnabled(this@MihomoVpnService, enabled)
            runCatching { Mobile.setLogLevel(if (enabled) "debug" else "silent") }
        }

        override fun registerCallback(cb: ITunnelCallback) = TunnelState.register(cb)
        override fun unregisterCallback(cb: ITunnelCallback) = TunnelState.unregister(cb)
    }

    // Always-on breaks unless the system's bind gets the default binder.
    override fun onBind(intent: Intent?): IBinder? =
        if (intent?.action == SERVICE_INTERFACE) super.onBind(intent) else binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        when (TunnelState.status) {
            TunnelState.CONNECTING, TunnelState.CONNECTED -> return START_STICKY
        }
        startForeground(1, buildNotification())
        TunnelState.set(TunnelState.CONNECTING)
        executor.execute { bringUp() }
        return START_STICKY
    }

    private fun bringUp() {
        try {
            val config = TunnelFiles.config(this).takeIf { it.exists() }?.readText()
                ?: throw IllegalStateException("no saved tunnel config to start from")

            val builder = Builder()
                .setSession("VPN")
                .setMtu(9000)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addAddress("fdfe:dcba:9876::1", 126)
                .addRoute("::", 0)
                // A public resolver makes automatic Private DNS switch to DoT and bypass dns-hijack.
                .addDnsServer("172.19.0.2")
            val pfd = builder.establish()
                ?: throw IllegalStateException("the system refused to establish the tunnel")
            val fd = pfd.detachFd()
            tunFd = fd

            Mobile.setSocketProtector(object : SocketProtector {
                override fun protect(sock: Long): Boolean {
                    val ok = this@MihomoVpnService.protect(sock.toInt())
                    if (!ok) log("protect failed for fd $sock")
                    return ok
                }
            })
            Mobile.setHomeDir(TunnelFiles.engineDir(this).absolutePath)
            redirectEngineOutput()
            Mobile.setLogLevel(if (TunnelFiles.logsEnabled(this)) "debug" else "silent")
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
            runCatching { Mobile.stop() }
            tunFd = null
            TunnelState.set(TunnelState.DISCONNECTED)
            log("tunnel down")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

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

    private fun redirectEngineOutput() {
        if (logStream != null) return
        try {
            val out = FileOutputStream(TunnelFiles.engineLog(this), true)
            Os.dup2(out.fd, 1)
            Os.dup2(out.fd, 2)
            logStream = out // held so GC does not close the fd
        } catch (e: Exception) {
            log("stdout redirect failed: ${e.message}")
        }
    }

    private fun log(line: String) {
        if (!TunnelFiles.logsEnabled(this)) return
        runCatching {
            val file = TunnelFiles.serviceLog(this)
            TunnelFiles.rotateIfNeeded(file)
            file.appendText("${java.time.LocalDateTime.now()} $line\n")
        }
    }

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
