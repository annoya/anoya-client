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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.system.Os
import android.system.OsConstants
import java.net.InetAddress
import java.net.InetSocketAddress
import java.io.FileOutputStream
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import mobile.Mobile
import mobile.PackageResolver
import mobile.SocketProtector

class MihomoVpnService : VpnService() {

    companion object {
        const val ACTION_START = "org.anoya.vpn.START"
        const val ACTION_STOP = "org.anoya.vpn.STOP"
        const val ACTION_RESTART = "org.anoya.vpn.RESTART"

        const val kTunnelOutbound = "PROXY"

        private const val ONGOING_ID = 1
        private const val SILENT_ID = 2
        private const val START_FAILED_ID = 3
        private const val ONGOING_CHANNEL = "vpn"
        private const val PROBLEMS_CHANNEL = "problems"
        private const val SILENCE_POLL_MS = 5_000L

        private val stamp: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var startedByApp = false

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
        if (intent?.action == ACTION_RESTART) {
            if (TunnelState.status != TunnelState.CONNECTED) return START_STICKY
            log("restart requested by the app to apply apps outside the VPN")
            startedByApp = true
            stopSilenceWatch()
            startForeground(ONGOING_ID, buildNotification(Ongoing.CONNECTING))
            TunnelState.set(TunnelState.CONNECTING)
            executor.execute { reestablish() }
            return START_STICKY
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
        startedByApp = intent?.action == ACTION_START
        startForeground(ONGOING_ID, buildNotification(Ongoing.CONNECTING))
        TunnelState.set(TunnelState.CONNECTING)
        executor.execute { bringUp() }
        return START_STICKY
    }

    private fun establish(): Int {
        val builder = Builder()
            .setSession("VPN")
            .setMtu(9000)
            .addAddress("172.19.0.1", 30)
            .addRoute("0.0.0.0", 0)
            .addAddress("fdfe:dcba:9876::1", 126)
            .addRoute("::", 0)
            // A public resolver makes automatic Private DNS switch to DoT and bypass dns-hijack.
            .addDnsServer("172.19.0.2")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)
        val excluded = TunnelFiles.excludedApps(this).filter { it != packageName }
        val missing = excluded.filter {
            runCatching { builder.addDisallowedApplication(it) }.isFailure
        }
        val pfd = builder.establish()
            ?: throw IllegalStateException("the system refused to establish the tunnel")
        val fd = pfd.detachFd()
        TunnelFiles.setExcludedAppsInUse(this, excluded)
        if (excluded.isNotEmpty()) {
            log("apps outside the VPN: ${excluded.size - missing.size}" +
                if (missing.isEmpty()) "" else ", ${missing.size} not installed")
        }
        return fd
    }

    private fun savedConfig(): String =
        TunnelFiles.config(this).takeIf { it.exists() }?.readText()
            ?: throw IllegalStateException("no saved tunnel config to start from")

    private fun reestablish() {
        try {
            val fd = establish()
            Mobile.reload(fd.toLong(), savedConfig())
            tunFd = fd
            TunnelState.set(TunnelState.CONNECTED)
            log("tunnel re-established on fd $fd")
            startSilenceWatch()
        } catch (e: Exception) {
            log("re-establish failed: ${e.message}")
            TunnelFiles.recordError(this, e.message ?: "re-establish failed")
            TunnelState.set(TunnelState.ERROR)
            shutdown()
        }
    }

    private fun bringUp() {
        try {
            val config = savedConfig()
            val fd = establish()
            tunFd = fd
            startNetworkLog()

            Mobile.setSocketProtector(object : SocketProtector {
                override fun protect(sock: Long): Boolean {
                    val ok = this@MihomoVpnService.protect(sock.toInt())
                    if (!ok) log("protect failed for fd $sock")
                    return ok
                }
            })
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) Mobile.setPackageResolver(ownerResolver)
            Mobile.setHomeDir(TunnelFiles.engineDir(this).absolutePath)
            Mobile.setEngineLog(TunnelFiles.engineLog(this).absolutePath)
            redirectEngineOutput()
            Mobile.setLogLevel(if (TunnelFiles.logsEnabled(this)) "debug" else "silent")
            log("starting engine on fd $fd")
            Mobile.start(fd.toLong(), config)
            TunnelFiles.clearError(this)
            TunnelState.set(TunnelState.CONNECTED)
            log("tunnel up · ${memory()}")
            notifications().cancel(START_FAILED_ID)
            startSilenceWatch()
        } catch (e: Exception) {
            log("start failed: ${e.message}")
            TunnelFiles.recordError(this, e.message ?: "start failed")
            if (!startedByApp) notifyStartFailed()
            TunnelState.set(TunnelState.ERROR)
            shutdown()
        }
    }

    fun shutdown() {
        executor.execute {
            val since = TunnelState.connectedSince
            main.post { stopSilenceWatch() }
            stopNetworkLog()
            TunnelFiles.runningMarker(this).delete()
            runCatching { Mobile.stop() }
            tunFd = null
            TunnelFiles.setExcludedAppsInUse(this, null)
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

    private val owners = ConcurrentHashMap<Int, String>()

    private val ownerResolver = object : PackageResolver {
        override fun ownerPackage(network: String, srcIP: String, srcPort: Long,
                                  dstIP: String, dstPort: Long): String {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return ""
            val cm = getSystemService(ConnectivityManager::class.java) ?: return ""
            val protocol = if (network == "udp") OsConstants.IPPROTO_UDP else OsConstants.IPPROTO_TCP
            val uid = runCatching {
                cm.getConnectionOwnerUid(
                    protocol,
                    InetSocketAddress(InetAddress.getByName(srcIP), srcPort.toInt()),
                    InetSocketAddress(InetAddress.getByName(dstIP), dstPort.toInt()),
                )
            }.getOrDefault(android.os.Process.INVALID_UID)
            if (uid == android.os.Process.INVALID_UID) return ""
            return owners.getOrPut(uid) { packageManager.getPackagesForUid(uid)?.firstOrNull() ?: "" }
        }
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

    private enum class Ongoing { CONNECTING, CONNECTED, SILENT }

    private fun notifications() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun openApp(action: String? = null): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (action != null) intent.putExtra(MainActivity.EXTRA_ACTION, action)
        return PendingIntent.getActivity(
            this, if (action == null) 0 else 1, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun buildNotification(state: Ongoing): Notification {
        val nm = notifications()
        nm.createNotificationChannel(
            NotificationChannel(ONGOING_CHANNEL, "VPN", NotificationManager.IMPORTANCE_LOW))
        val notice = TunnelFiles.notice(this)
        val configuration = notice["configuration"]?.takeIf { it.isNotEmpty() }
        val (title, text) = when (state) {
            Ongoing.CONNECTING -> (configuration ?: "VPN") to null
            Ongoing.CONNECTED -> (notice["connected"] ?: "VPN") to configuration
            Ongoing.SILENT -> (notice["connected_silent"] ?: "VPN") to notice["connected_silent_detail"]
        }
        return Notification.Builder(this, ONGOING_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(getColor(R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openApp(if (state == Ongoing.SILENT) MainActivity.ACTION_SERVER_PICKER else null))
            .setOngoing(true)
            .build()
    }

    private fun notifyProblem(id: Int, title: String, body: String, action: String?) {
        val nm = notifications()
        val channelName = TunnelFiles.notice(this)["channel_problems"] ?: "Connection problems"
        nm.createNotificationChannel(
            NotificationChannel(PROBLEMS_CHANNEL, channelName, NotificationManager.IMPORTANCE_HIGH))
        nm.notify(id, Notification.Builder(this, PROBLEMS_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(getColor(R.color.notification_accent))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(openApp(action))
            .setAutoCancel(true)
            .build())
    }

    private fun notifyStartFailed() {
        val notice = TunnelFiles.notice(this)
        notifyProblem(
            START_FAILED_ID,
            notice["start_failed_title"] ?: "The VPN could not start",
            notice["start_failed_body"] ?: "Open Anoya to see why.",
            null,
        )
    }

    private var silent = false
    private var shownOngoing: String? = null

    private val silenceWatch = object : Runnable {
        override fun run() {
            if (TunnelState.status != TunnelState.CONNECTED) return
            val now = runCatching { Mobile.serverSilent() }.getOrDefault(false)
            if (now != silent) {
                silent = now
                if (now) {
                    val notice = TunnelFiles.notice(this@MihomoVpnService)
                    notifyProblem(
                        SILENT_ID,
                        notice["silent_title"] ?: "The server is not answering",
                        notice["silent_body"] ?: "",
                        MainActivity.ACTION_SERVER_PICKER,
                    )
                    log("told the person: the server is not answering")
                } else {
                    notifications().cancel(SILENT_ID)
                    log("the server answers again; the notice is withdrawn")
                }
            }
            showOngoing(if (silent) Ongoing.SILENT else Ongoing.CONNECTED)
            main.postDelayed(this, SILENCE_POLL_MS)
        }
    }

    private fun showOngoing(state: Ongoing) {
        val notice = TunnelFiles.notice(this)
        val key = "$state ${notice["connected"]} ${notice["configuration"]}"
        if (key == shownOngoing) return
        shownOngoing = key
        notifications().notify(ONGOING_ID, buildNotification(state))
    }

    private fun startSilenceWatch() {
        main.post {
            main.removeCallbacks(silenceWatch)
            silent = false
            shownOngoing = null
            silenceWatch.run()
        }
    }

    private fun stopSilenceWatch() {
        main.removeCallbacks(silenceWatch)
        silent = false
        shownOngoing = null
        notifications().cancel(SILENT_ID)
    }

}
