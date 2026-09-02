package org.annoya.vpn_client

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/// The Android leg of the OIDC flow, behind the same "vpn/web_auth" contract
/// as the Apple ASWebAuthenticationSession: start({url, scheme}) answers with
/// the redirect URL the identity provider sent the browser to.
///
/// Android has no system auth sheet. The login page opens in the user's
/// browser, and the redirect to our scheme (vpnclient://auth?code=...) comes
/// back through [WebAuthCallbackActivity], declared in the manifest for that
/// scheme. The browser stays open behind the app afterwards; that is the
/// platform's own behaviour for every app that signs in this way.
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
            // A second start while one is out replaces it: the first browser tab
            // can no longer answer anything the app is waiting for.
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

    /// The identity provider redirected to our scheme.
    fun onCallback(uri: Uri?) {
        val result = pending ?: return
        pending = null
        if (uri == null) {
            result.error("auth_failed", "empty redirect", null)
        } else {
            result.success(uri.toString())
        }
    }

    /// The app came back to the foreground without a redirect: the user closed
    /// the browser or backed out of the sign-in page.
    fun onHostResumed() {
        val result = pending ?: return
        pending = null
        result.error("cancelled", "user cancelled", null)
    }
}
