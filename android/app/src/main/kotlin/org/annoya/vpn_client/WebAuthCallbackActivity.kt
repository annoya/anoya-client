package org.annoya.vpn_client

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/// Receives the vpnclient://auth redirect from the browser, hands it to
/// [WebAuthChannel] and brings the app back on top. Invisible: it exists only
/// because an intent filter needs an activity to point at, and the browser
/// launches it in its own task where MainActivity cannot receive the intent
/// without being recreated.
class WebAuthCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WebAuthChannel.onCallback(intent?.data)
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        )
        finish()
    }
}
