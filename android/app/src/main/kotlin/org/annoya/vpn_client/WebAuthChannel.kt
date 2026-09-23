package org.annoya.vpn_client

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

object WebAuthChannel {
    private var pending: MethodChannel.Result? = null
    private var host = WeakReference<Activity>(null)

    fun register(messenger: BinaryMessenger, activity: Activity) {
        host = WeakReference(activity)
        MethodChannel(messenger, "vpn/web_auth").setMethodCallHandler { call, result ->
            if (call.method != "start") return@setMethodCallHandler result.notImplemented()
            val url = call.argument<String>("url")
            if (url.isNullOrEmpty()) {
                return@setMethodCallHandler result.error("bad_args", "url and scheme required", null)
            }
            val activity = host.get()
                ?: return@setMethodCallHandler result.error("start_failed", "no activity", null)
            pending?.error("cancelled", "superseded", null)
            pending = result
            try {
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            } catch (e: Exception) {
                pending = null
                result.error("start_failed", "no browser to open the sign-in page", null)
            }
        }
    }

    fun unregister(activity: Activity) {
        if (host.get() === activity) host = WeakReference(null)
        pending?.error("cancelled", "screen closed", null)
        pending = null
    }

    fun onCallback(uri: Uri?) {
        val result = pending ?: return
        pending = null
        if (uri == null) {
            result.error("auth_failed", "empty redirect", null)
        } else {
            result.success(uri.toString())
        }
    }

    fun onHostResumed() {
        val result = pending ?: return
        pending = null
        result.error("cancelled", "user cancelled", null)
    }
}
