package org.anoya.vpn;

/** Status pushed from the tunnel process to the app. */
oneway interface ITunnelCallback {
    void onStatus(String status);
}
