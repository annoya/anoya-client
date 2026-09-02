package org.annoya.vpn_client

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// VpnChannel bridges Flutter <-> the tunnel process, speaking the same
/// "vpn/control" / "vpn/status" contract as the Apple side, so the Dart core
/// does not know which platform it is on.
///
/// The tunnel lives in `:tunnel`, so every question for it is a binder call.
/// Two rules follow. Binder calls block, so they run on [calls] and never on
/// the UI thread. And the tunnel process can die without taking the app with
/// it — that is the point of the split — so a lost binding is a state the app
/// reports rather than a state it crashes in.
///
/// Starting is not a binder call: the app sends the same Intent the system
/// sends for always-on, and the service reads the config from disk either way.
object VpnChannel {

    private var pendingStart: MethodChannel.Result? = null
    const val PREPARE_REQUEST = 24001
    const val NOTIFICATIONS_REQUEST = 24002

    /// Binder calls block for as long as the tunnel process takes to answer —
    /// a config parse, in the worst case. Never the UI thread.
    private val calls = Executors.newSingleThreadExecutor()

    @Volatile private var tunnel: ITunnel? = null
    @Volatile private var lastStatus: String = TunnelState.DISCONNECTED
    private var events: EventChannel.EventSink? = null
    private var host: Activity? = null

    private val callback = object : ITunnelCallback.Stub() {
        override fun onStatus(status: String) {
            lastStatus = status
            host?.runOnUiThread {
                events?.success(status)
                if (status == TunnelState.CONNECTED) {
                    host?.let { maybeAskForNotifications(it) }
                }
            }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val t = ITunnel.Stub.asInterface(service)
            tunnel = t
            // Registering also delivers what is true right now: the app may
            // have just been opened over a tunnel the system started hours ago.
            calls.execute { runCatching { t.registerCallback(callback) } }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            // The tunnel process died — crashed, or was killed after it
            // stopped. Either way nothing is carrying traffic now, and saying
            // so is the honest answer; `disconnect_error` explains why when
            // there was a reason.
            tunnel = null
            lastStatus = TunnelState.DISCONNECTED
            host?.runOnUiThread { events?.success(TunnelState.DISCONNECTED) }
        }
    }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        host = activity
        val context = activity.applicationContext
        // Bound from the start, with AUTO_CREATE: binding creates the service
        // but does not start a tunnel (onStartCommand is what does), so this
        // costs an idle process and buys a live status the moment the app opens.
        context.bindService(
            Intent(context, MihomoVpnService::class.java), connection, Context.BIND_AUTO_CREATE)

        val control = MethodChannel(messenger, "vpn/control")
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> result.success(null) // consent is asked on start, where it is needed
                "start" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    persist(context, config, call.argument<Boolean>("log_enabled") ?: true)
                    val consent = VpnService.prepare(context)
                    if (consent == null) {
                        startService(context); result.success(null)
                    } else {
                        // The dialog belongs to the system; the answer comes
                        // back through the Activity, which finishes this call.
                        pendingStart = result
                        activity.startActivityForResult(consent, PREPARE_REQUEST)
                    }
                }
                "stop" -> ask(result) { it.stop(); null }
                "reload" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    persist(context, config, call.argument<Boolean>("log_enabled") ?: true)
                    calls.execute {
                        val t = tunnel
                        val err = if (t == null) "tunnel is not running"
                                  else runCatching { t.reload(config) }
                                      .getOrElse { it.message ?: "reload failed" }
                        activity.runOnUiThread {
                            if (err.isEmpty()) result.success(null)
                            else result.error("reload_failed", err, null)
                        }
                    }
                }
                "sync_config" -> {
                    // Keep the saved config in step with the selection so an
                    // always-on start never resurrects a stale one — the same
                    // job sync does for the NE profile on Apple.
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    persist(context, config, call.argument<Boolean>("log_enabled") ?: true)
                    result.success(null)
                }
                "remove_profile" -> {
                    // No system profile to remove on Android; what must not
                    // outlive the last configuration is the saved config an
                    // always-on start would run.
                    calls.execute {
                        runCatching { tunnel?.stop() }
                        TunnelFiles.config(context).delete()
                        activity.runOnUiThread { result.success(null) }
                    }
                }
                // Android's counterpart is always-on, and it is the system's
                // own switch — an app can only point at it. Never armed here.
                "set_on_demand" -> result.success(false)
                "is_always_on" -> ask(result, orElse = false) { it.isAlwaysOn() }
                "open_vpn_settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                    result.success(null)
                }
                // Answered from the app's own copy: it is what the last
                // callback said, and it is still right when the tunnel process
                // is gone (there is nothing to ask, and nothing running).
                "status" -> result.success(lastStatus)
                "connected_since" -> ask(result, orElse = 0.0) { it.connectedSince() }
                "disconnect_error" -> result.success(TunnelFiles.lastError(context))
                "group_member" -> {
                    val name = call.argument<String>("group") ?: ""
                    ask(result, orElse = "") { it.groupMember(name) }
                }
                "proxy_bytes" -> ask(result, orElse = "0:0") { it.proxyBytes() }
                "url_test" -> {
                    val url = call.argument<String>("url") ?: ""
                    val timeout = call.argument<Int>("timeout_ms") ?: 5000
                    ask(result, orElse = "err:the tunnel is not running") {
                        it.urlTest(url, timeout)
                    }
                }
                "device_info" -> result.success(mapOf(
                    "os" to "Android",
                    "version" to Build.VERSION.RELEASE,
                    "model" to Build.MODEL,
                ))
                "shared_dir" -> result.success(TunnelFiles.engineDir(context).absolutePath)
                "set_logging" -> {
                    val on = call.argument<Boolean>("enabled") ?: true
                    // Written here as well as pushed: with no tunnel running
                    // there is nobody to tell, and the next start must still
                    // honour the switch.
                    TunnelFiles.setLogsEnabled(context, on)
                    ask(result) { it.setLogging(on); null }
                }
                "clear_logs" -> {
                    // The logs are files in the app's own sandbox, so unlike
                    // the Apple extension this works with the tunnel down.
                    TunnelFiles.engineLog(context).writeText("")
                    TunnelFiles.serviceLog(context).writeText("")
                    result.success(null)
                }
                "fetch_log" -> {
                    val file = when (call.argument<String>("name") ?: "") {
                        "mihomo" -> TunnelFiles.engineLog(context)
                        else -> TunnelFiles.serviceLog(context)
                    }
                    result.success(if (file.exists()) file.readText() else "")
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "vpn/status").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                events = sink
                sink.success(lastStatus)
            }
            override fun onCancel(args: Any?) {
                events = null
            }
        })
    }

    /// One binder question, off the UI thread, with an answer for the case
    /// where there is no tunnel process to ask.
    private fun ask(result: MethodChannel.Result, orElse: Any? = null,
                    body: (ITunnel) -> Any?) {
        val activity = host ?: return result.success(orElse)
        calls.execute {
            val t = tunnel
            val value = if (t == null) orElse
                        else runCatching { body(t) }.getOrDefault(orElse)
            activity.runOnUiThread { result.success(value) }
        }
    }

    fun onVpnPermissionResult(context: Context, resultCode: Int) {
        val pending = pendingStart ?: return
        pendingStart = null
        if (resultCode == Activity.RESULT_OK) {
            startService(context)
            pending.success(null)
        } else {
            pending.error("start_failed", "VPN permission was declined", null)
        }
    }

    /// Asked on the first successful connect — the moment the foreground
    /// notification exists to be seen, and the ask explains itself. Without
    /// the permission (a runtime one since Android 13) the tunnel still runs;
    /// only the shade entry is silently dropped. Asked once: a refusal is an
    /// answer, not a retry schedule.
    fun maybeAskForNotifications(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33) return
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) return
        val prefs = activity.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
        if (prefs.getBoolean("notifications_asked", false)) return
        prefs.edit().putBoolean("notifications_asked", true).apply()
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATIONS_REQUEST)
    }

    private fun startService(context: Context) {
        context.startForegroundService(
            Intent(context, MihomoVpnService::class.java).setAction(MihomoVpnService.ACTION_START))
    }

    private fun persist(context: Context, config: String, logEnabled: Boolean) {
        TunnelFiles.config(context).writeText(config)
        TunnelFiles.setLogsEnabled(context, logEnabled)
    }
}
