package org.anoya.vpn

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

object VpnChannel {

    private var pendingStart: MethodChannel.Result? = null
    const val PREPARE_REQUEST = 24001
    const val NOTIFICATIONS_REQUEST = 24002

    private val calls = Executors.newSingleThreadExecutor()

    private val probes = Executors.newCachedThreadPool()

    @Volatile private var tunnel: ITunnel? = null
    @Volatile private var lastStatus: String = TunnelState.DISCONNECTED
    private var events: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())

    private var host = WeakReference<Activity>(null)

    private var bound = false

    private val callback = object : ITunnelCallback.Stub() {
        override fun onStatus(status: String) {
            lastStatus = status
            main.post {
                events?.success(status)
                if (status == TunnelState.CONNECTED) {
                    host.get()?.let { maybeAskForNotifications(it) }
                }
            }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val t = ITunnel.Stub.asInterface(service)
            tunnel = t
            calls.execute { runCatching { t.registerCallback(callback) } }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            tunnel = null
            lastStatus = TunnelState.DISCONNECTED
            main.post { events?.success(TunnelState.DISCONNECTED) }
        }
    }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        host = WeakReference(activity)
        val context = activity.applicationContext
        if (!bound) {
            bound = context.bindService(
                Intent(context, MihomoVpnService::class.java), connection, Context.BIND_AUTO_CREATE)
        }

        val control = MethodChannel(messenger, "vpn/control")
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    val logEnabled = call.argument<Boolean>("log_enabled") ?: true
                    calls.execute {
                        persist(context, config, logEnabled)
                        main.post {
                            val consent = VpnService.prepare(context)
                            val act = host.get()
                            if (consent == null) {
                                startService(context); result.success(null)
                            } else if (act == null) {
                                result.error("start_failed", "no screen to ask for VPN permission on", null)
                            } else {
                                pendingStart = result
                                act.startActivityForResult(consent, PREPARE_REQUEST)
                            }
                        }
                    }
                }
                "stop" -> ask(result) { it.stop(); null }
                "reload" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    val logEnabled = call.argument<Boolean>("log_enabled") ?: true
                    calls.execute {
                        val t = tunnel
                        val err = if (t == null) "tunnel is not running"
                                  else runCatching { t.reload(config) }
                                      .getOrElse { it.message ?: "reload failed" }
                        if (err.isEmpty()) persist(context, config, logEnabled)
                        main.post {
                            if (err.isEmpty()) result.success(null)
                            else result.error("reload_failed", err, null)
                        }
                    }
                }
                "sync_config" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    val logEnabled = call.argument<Boolean>("log_enabled") ?: true
                    io(result) { persist(context, config, logEnabled); null }
                }
                "remove_profile" -> {
                    calls.execute {
                        runCatching { tunnel?.stop() }
                        TunnelFiles.config(context).delete()
                        main.post { result.success(null) }
                    }
                }
                "set_on_demand" -> result.success(false)
                "open_vpn_settings" -> {
                    context.startActivity(
                        Intent(Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
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
                    ask(result, orElse = "err:the tunnel is not running", on = probes) {
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
                    calls.execute { TunnelFiles.setLogsEnabled(context, on) }
                    ask(result) { it.setLogging(on); null }
                }
                "clear_logs" -> io(result) {
                    TunnelFiles.engineLog(context).writeText("")
                    TunnelFiles.serviceLog(context).writeText("")
                    null
                }
                "fetch_log" -> {
                    val file = when (call.argument<String>("name") ?: "") {
                        "mihomo" -> TunnelFiles.engineLog(context)
                        else -> TunnelFiles.serviceLog(context)
                    }
                    io(result) { TunnelFiles.tail(file) }
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

    private fun ask(result: MethodChannel.Result, orElse: Any? = null,
                    on: java.util.concurrent.Executor = calls, body: (ITunnel) -> Any?) {
        on.execute {
            val t = tunnel
            val value = if (t == null) orElse
                        else runCatching { body(t) }.getOrDefault(orElse)
            main.post { result.success(value) }
        }
    }

    private fun io(result: MethodChannel.Result, body: () -> Any?) {
        calls.execute {
            val value = runCatching(body).getOrNull()
            main.post { result.success(value) }
        }
    }

    fun unregister(activity: Activity) {
        if (host.get() === activity) host = WeakReference(null)
        events = null
        pendingStart = null
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
