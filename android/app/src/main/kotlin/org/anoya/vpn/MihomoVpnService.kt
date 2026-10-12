package org.anoya.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.system.Os
import java.io.FileOutputStream
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import mobile.Mobile
import mobile.SocketProtector

class MihomoVpnService : VpnService() {

    companion object {
        const val ACTION_START = "org.anoya.vpn.START"
        const val ACTION_STOP = "org.anoya.vpn.STOP"

        const val kTunnelOutbound = "PROXY"

        private val stamp: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)
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
            applyJournal()
        }

        override fun registerCallback(cb: ITunnelCallback) = TunnelState.register(cb)
        override fun unregisterCallback(cb: ITunnelCallback) = TunnelState.unregister(cb)
    }

    // Always-on breaks unless the system's bind gets the default binder.
    override fun onBind(intent: Intent?): IBinder? =
        if (intent?.action == SERVICE_INTERFACE) super.onBind(intent) else binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            log("stop requested by the app")
            shutdown()
            return START_NOT_STICKY
        }
        val by = when (intent?.action) {
            null -> "the system (service restarted)"
            ACTION_START -> "the app"
            SERVICE_INTERFACE -> "always-on VPN"
            else -> "unknown action"
        }
        when (TunnelState.status) {
            TunnelState.CONNECTING, TunnelState.CONNECTED -> return START_STICKY
        }
        applyJournal()
        log("start requested by $by · pid ${android.os.Process.myPid()}")
        checkPreviousRun()
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
            startNetworkLog()

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
            log("tunnel up · ${memory()}")
        } catch (e: Exception) {
            log("start failed: ${e.message}")
            TunnelFiles.recordError(this, e.message ?: "start failed")
            TunnelState.set(TunnelState.ERROR)
            shutdown()
        }
    }

    fun shutdown() {
        executor.execute {
            val since = TunnelState.connectedSince
            stopNetworkLog()
            TunnelFiles.runningMarker(this).delete()
            runCatching { Mobile.stop() }
            tunFd = null
            TunnelState.set(TunnelState.DISCONNECTED)
            val uptime = if (since > 0) " after ${duration(System.currentTimeMillis() / 1000.0 - since)}" else ""
            log("tunnel down$uptime")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    override fun onRevoke() {
        log("revoked by the system (another VPN app, or turned off in settings)")
        TunnelFiles.recordError(this,
            "the system revoked the VPN (another VPN app, or turned off in settings)")
        shutdown()
    }

    override fun onDestroy() {
        log("service destroyed")
        stopNetworkLog()
        executor.shutdown()
        super.onDestroy()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        @Suppress("DEPRECATION")
        val name = when (level) {
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> "running critical"
            ComponentCallbacks2.TRIM_MEMORY_COMPLETE -> "complete"
            else -> return
        }
        log("memory pressure: $name · ${memory()}")
    }

    override fun onLowMemory() {
        super.onLowMemory()
        log("low memory · ${memory()}")
    }

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private val networks = ConcurrentHashMap<Network, String>()

    private fun startNetworkLog() {
        stopNetworkLog()
        val cm = getSystemService(ConnectivityManager::class.java) ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) =
                report(network, describe(caps, cm.getLinkProperties(network)))

            override fun onLinkPropertiesChanged(network: Network, link: LinkProperties) =
                report(network, describe(cm.getNetworkCapabilities(network), link))

            override fun onLost(network: Network) {
                val last = networks.remove(network) ?: "unknown"
                log("network lost: $last")
            }

            override fun onUnavailable() = log("network: none available")
        }
        runCatching { cm.registerNetworkCallback(request, callback) }
            .onSuccess { networkCallback = callback }
            .onFailure { log("network monitor unavailable: ${it.message}") }
    }

    private fun stopNetworkLog() {
        val callback = networkCallback ?: return
        networkCallback = null
        networks.clear()
        runCatching { getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(callback) }
    }

    private fun report(network: Network, text: String) {
        val previous = networks.put(network, text)
        if (previous == text) return
        log(if (previous == null) "network available: $text" else "network changed: $text")
    }

    private fun describe(caps: NetworkCapabilities?, link: LinkProperties?): String {
        val parts = mutableListOf<String>()
        parts += link?.interfaceName ?: "?"
        if (caps != null) {
            parts += when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
            parts += if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) "validated"
                else "not validated"
        }
        return parts.joinToString(" · ")
    }

    private fun applyJournal() {
        val on = TunnelFiles.logsEnabled(this)
        runCatching { Mobile.setJournal(if (on) TunnelFiles.serviceLog(this).absolutePath else "") }
    }

    private fun checkPreviousRun() {
        val marker = TunnelFiles.runningMarker(this)
        val previous = runCatching { marker.readText() }.getOrNull()
        if (previous != null) {
            val pid = Regex("pid (\\d+)").find(previous)?.groupValues?.get(1)?.toIntOrNull()
            log("previous tunnel process ($previous) ended without a stop: ${previousExit(pid)}")
        }
        runCatching {
            marker.writeText("pid ${android.os.Process.myPid()}, started ${stamp.format(Instant.now())}")
        }
    }

    private fun previousExit(pid: Int?): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return "killed by the system or crashed"
        val am = getSystemService(android.app.ActivityManager::class.java)
        val exit = runCatching { am.getHistoricalProcessExitReasons(packageName, 0, 10) }
            .getOrDefault(emptyList())
            .firstOrNull { it.processName.endsWith(":tunnel") && it.pid == pid }
            ?: return "no exit record from the system"
        val reason = when (exit.reason) {
            android.app.ApplicationExitInfo.REASON_LOW_MEMORY -> "killed for low memory"
            android.app.ApplicationExitInfo.REASON_CRASH -> "crashed (java)"
            android.app.ApplicationExitInfo.REASON_CRASH_NATIVE -> "crashed (native)"
            android.app.ApplicationExitInfo.REASON_ANR -> "not responding (ANR)"
            android.app.ApplicationExitInfo.REASON_SIGNALED -> "killed by signal ${exit.status}"
            android.app.ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "killed for excessive resource usage"
            android.app.ApplicationExitInfo.REASON_USER_REQUESTED -> "stopped by the user (force stop or app update)"
            android.app.ApplicationExitInfo.REASON_USER_STOPPED -> "stopped by the user"
            android.app.ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "killed after a permission change"
            android.app.ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "a dependency died"
            android.app.ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "failed to initialize"
            android.app.ApplicationExitInfo.REASON_EXIT_SELF -> "exited by itself (code ${exit.status})"
            android.app.ApplicationExitInfo.REASON_FREEZER -> "killed while frozen"
            android.app.ApplicationExitInfo.REASON_OTHER -> "killed by the system"
            else -> "exit reason ${exit.reason}"
        }
        val pss = if (exit.pss > 0) " · pss %.1f MB".format(exit.pss / 1024.0) else ""
        val note = exit.description?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""
        return "$reason at ${stamp.format(Instant.ofEpochMilli(exit.timestamp))}$pss$note"
    }

    private fun memory(): String {
        val rt = Runtime.getRuntime()
        val info = android.os.Debug.MemoryInfo().also { android.os.Debug.getMemoryInfo(it) }
        return "pss %.1f MB, java heap %.1f MB".format(
            info.totalPss / 1024.0, (rt.totalMemory() - rt.freeMemory()) / 1048576.0)
    }

    private fun duration(seconds: Double): String {
        val total = seconds.toLong()
        val h = total / 3600
        val m = total / 60 % 60
        val s = total % 60
        return when {
            h > 0 -> "${h}h${m}m${s}s"
            m > 0 -> "${m}m${s}s"
            else -> "${s}s"
        }
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
            file.appendText("${stamp.format(Instant.now())} $line\n")
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
