package org.anoya.vpn;

import org.anoya.vpn.ITunnelCallback;

interface ITunnel {
    void stop();

    String reload(String config);

    double connectedSince();

    String groupMember(String group);

    String urlTest(String url, int timeoutMs);

    String proxyBytes();

    void setLogging(boolean enabled);

    void registerCallback(ITunnelCallback cb);
    void unregisterCallback(ITunnelCallback cb);
}
