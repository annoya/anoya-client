package org.anoya.vpn

import android.os.RemoteCallbackList

// Only the tunnel process's copy is real; the app sees it via ITunnelCallback.
object TunnelState {
    const val DISCONNECTED = "disconnected"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
    const val ERROR = "error"

    @Volatile var status: String = DISCONNECTED
        private set

    @Volatile var connectedSince: Double = 0.0
        private set

    private val callbacks = RemoteCallbackList<ITunnelCallback>()

    fun register(cb: ITunnelCallback) {
        callbacks.register(cb)
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
