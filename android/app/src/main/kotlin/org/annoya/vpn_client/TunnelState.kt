package org.annoya.vpn_client

import android.content.Context

/// The one place both halves of the app read the tunnel's state from.
///
/// On Apple the tunnel lives in another process and the system relays its
/// status; here the VpnService runs inside this very process, so the "relay"
/// is a singleton. The service writes, the Flutter channel reads and streams.
object TunnelState {
    const val DISCONNECTED = "disconnected"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
    const val ERROR = "error"

    @Volatile var status: String = DISCONNECTED
        private set

    /// Epoch seconds of the moment the tunnel came up, 0 when it is not up.
    /// Kept here rather than stamped by the UI: an always-on start happens
    /// with no Flutter engine running, and the clock must count from the
    /// connect, not from whenever the app was next opened.
    @Volatile var connectedSince: Double = 0.0
        private set

    private val listeners = mutableSetOf<(String) -> Unit>()

    @Synchronized fun addListener(l: (String) -> Unit) { listeners.add(l); l(status) }
    @Synchronized fun removeListener(l: (String) -> Unit) { listeners.remove(l) }

    @Synchronized fun set(newStatus: String) {
        status = newStatus
        connectedSince =
            if (newStatus == CONNECTED) System.currentTimeMillis() / 1000.0 else 0.0
        listeners.forEach { it(newStatus) }
    }

    /// Why the tunnel last stopped on its own. Persisted, not held in memory:
    /// the process that failed and the process the user asks are not always
    /// the same one.
    fun recordError(context: Context, message: String) {
        prefs(context).edit().putString("disconnect_error", message).apply()
    }

    fun lastError(context: Context): String =
        prefs(context).getString("disconnect_error", "") ?: ""

    fun clearError(context: Context) {
        prefs(context).edit().remove("disconnect_error").apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
}
