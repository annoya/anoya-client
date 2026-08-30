package org.annoya.vpn_client

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VpnChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VpnChannel.PREPARE_REQUEST) {
            VpnChannel.onVpnPermissionResult(applicationContext, resultCode)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
