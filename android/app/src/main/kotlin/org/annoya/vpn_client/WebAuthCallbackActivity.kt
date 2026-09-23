package org.annoya.vpn_client

import android.app.Activity
import android.content.Intent
import android.os.Bundle

// Separate activity: the browser launches it in its own task, where
// MainActivity could not receive the intent without being recreated.
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
