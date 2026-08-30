package org.annoya.vpn_client

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// VpnChannel bridges Flutter <-> MihomoVpnService, speaking the same
/// "vpn/control" / "vpn/status" contract as the Apple side, so the Dart core
/// does not know which platform it is on.
///
/// The one Android-only step is consent: the first start must go through
/// VpnService.prepare()'s system dialog, which needs an Activity result — the
/// pending start waits in [onVpnPermissionResult] until the user answers.
object VpnChannel {

    private var pendingStart: MethodChannel.Result? = null
    const val PREPARE_REQUEST = 24001
    const val NOTIFICATIONS_REQUEST = 24002

    /// Kept so a re-register (Activity recreated) replaces the listener
    /// instead of stacking a second one.
    private var connectListener: ((String) -> Unit)? = null

    fun register(messenger: BinaryMessenger, activity: Activity) {
        val context = activity.applicationContext

        // Ask to show notifications on the first successful connect — the
        // moment the foreground notification exists to be seen, and the ask
        // explains itself. Without the permission (a runtime one since
        // Android 13) the tunnel still runs; only the shade entry is silently
        // dropped. Asked once: a refusal is an answer, not a retry schedule.
        connectListener?.let { TunnelState.removeListener(it) }
        val onConnected: (String) -> Unit = { s ->
            if (s == TunnelState.CONNECTED) {
                activity.runOnUiThread { maybeAskForNotifications(activity) }
            }
        }
        connectListener = onConnected
        TunnelState.addListener(onConnected)
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
                "stop" -> {
                    MihomoVpnService.instance?.shutdown()
                    result.success(null)
                }
                "reload" -> {
                    val config = call.argument<String>("config")
                    if (config == null) {
                        result.error("bad_args", "config required", null); return@setMethodCallHandler
                    }
                    persist(context, config, call.argument<Boolean>("log_enabled") ?: true)
                    val service = MihomoVpnService.instance
                    if (service == null) {
                        result.error("reload_failed", "tunnel is not running", null)
                    } else {
                        service.reload(config) { err ->
                            activity.runOnUiThread {
                                if (err == null) result.success(null)
                                else result.error("reload_failed", err.message, null)
                            }
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
                    MihomoVpnService.instance?.shutdown()
                    MihomoVpnService.configFile(context).delete()
                    result.success(null)
                }
                "set_on_demand" -> {
                    // Android's counterpart is always-on, and it is the
                    // system's own switch — an app can only point at it.
                    // Never armed from here.
                    result.success(false)
                }
                "is_always_on" -> {
                    val service = MihomoVpnService.instance
                    result.success(
                        Build.VERSION.SDK_INT >= 29 && service != null && service.isAlwaysOn)
                }
                "open_vpn_settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                    result.success(null)
                }
                "status" -> result.success(TunnelState.status)
                "connected_since" -> result.success(TunnelState.connectedSince)
                "disconnect_error" -> result.success(TunnelState.lastError(context))
                "group_member" -> {
                    val name = call.argument<String>("group") ?: ""
                    result.success(
                        if (TunnelState.status == TunnelState.CONNECTED)
                            mobile.Mobile.groupMember(name)
                        else "")
                }
                "device_info" -> result.success(mapOf(
                    "os" to "Android",
                    "version" to Build.VERSION.RELEASE,
                    "model" to Build.MODEL,
                ))
                "shared_dir" -> result.success(MihomoVpnService.engineDir(context).absolutePath)
                "set_logging" -> {
                    val on = call.argument<Boolean>("enabled") ?: true
                    context.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
                        .edit().putBoolean("log_enabled", on).apply()
                    mobile.Mobile.setLogLevel(if (on) "info" else "silent")
                    result.success(null)
                }
                "clear_logs" -> {
                    // In-process, so unlike the Apple extension this works
                    // whether or not the tunnel is up.
                    MihomoVpnService.engineLogFile(context).writeText("")
                    MihomoVpnService.serviceLogFile(context).writeText("")
                    result.success(null)
                }
                "fetch_log" -> {
                    val name = call.argument<String>("name") ?: ""
                    val file = when (name) {
                        "mihomo" -> MihomoVpnService.engineLogFile(context)
                        else -> MihomoVpnService.serviceLogFile(context)
                    }
                    result.success(if (file.exists()) file.readText() else "")
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "vpn/status").setStreamHandler(object : EventChannel.StreamHandler {
            private var listener: ((String) -> Unit)? = null
            override fun onListen(args: Any?, events: EventChannel.EventSink) {
                val l: (String) -> Unit = { s -> activity.runOnUiThread { events.success(s) } }
                listener = l
                TunnelState.addListener(l)
            }
            override fun onCancel(args: Any?) {
                listener?.let { TunnelState.removeListener(it) }
                listener = null
            }
        })
    }

    private fun maybeAskForNotifications(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33) return
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) return
        val prefs = activity.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
        if (prefs.getBoolean("notifications_asked", false)) return
        prefs.edit().putBoolean("notifications_asked", true).apply()
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATIONS_REQUEST)
    }

    fun onVpnPermissionResult(context: Context, resultCode: Int) {
        val pending = pendingStart ?: return
        pendingStart = null
        if (resultCode == Activity.RESULT_OK) {
            startService(context)
            pending.success(null)
        } else {
            TunnelState.set(TunnelState.DISCONNECTED)
            pending.error("start_failed", "VPN permission was declined", null)
        }
    }

    private fun startService(context: Context) {
        context.startForegroundService(
            Intent(context, MihomoVpnService::class.java).setAction(MihomoVpnService.ACTION_START))
    }

    private fun persist(context: Context, config: String, logEnabled: Boolean) {
        MihomoVpnService.configFile(context).writeText(config)
        context.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
            .edit().putBoolean("log_enabled", logEnabled).apply()
    }
}
