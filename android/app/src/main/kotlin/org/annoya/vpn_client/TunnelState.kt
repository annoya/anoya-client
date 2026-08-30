package org.annoya.vpn_client

import android.os.RemoteCallbackList

/// The tunnel's state, owned by the tunnel process.
///
/// This object exists once per process and only the tunnel process's copy is
/// real — the app learns about it over [ITunnelCallback], the way the Apple
/// app learns from the extension through the system. Nothing here is
/// persisted: a fact that must survive the process dying belongs in
/// [TunnelFiles].
object TunnelState {
    const val DISCONNECTED = "disconnected"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
    const val ERROR = "error"

    @Volatile var status: String = DISCONNECTED
        private set

    /// Epoch seconds of the moment the tunnel came up, 0 when it is not up.
    /// Kept here rather than stamped by the UI: an always-on start happens
    /// with no app running, and the clock must count from the connect, not
    /// from whenever the app was next opened.
    @Volatile var connectedSince: Double = 0.0
        private set

    private val callbacks = RemoteCallbackList<ITunnelCallback>()

    fun register(cb: ITunnelCallback) {
        callbacks.register(cb)
        // What is true right now, before anything changes: a binding may open
        // over a tunnel that has been up for hours.
        runCatching { cb.onStatus(status) }
    }

    fun unregister(cb: ITunnelCallback) {
        callbacks.unregister(cb)
    }

    @Synchronized fun set(newStatus: String) {
        status = newStatus
        connectedSince =
            if (newStatus == CONNECTED) System.currentTimeMillis() / 1000.0 else 0.0
        val n = callbacks.beginBroadcast()
        for (i in 0 until n) {
            runCatching { callbacks.getBroadcastItem(i).onStatus(newStatus) }
        }
        callbacks.finishBroadcast()
    }
}
