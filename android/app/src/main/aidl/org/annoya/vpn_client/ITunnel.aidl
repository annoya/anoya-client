package org.annoya.vpn_client;

import org.annoya.vpn_client.ITunnelCallback;

/**
 * What the app may ask of the tunnel process.
 *
 * Starting is deliberately NOT here: a start arrives as an Intent, because the
 * system sends the same one for always-on and the tunnel must not need the app
 * to be alive. Everything below only makes sense while a tunnel process
 * exists, which is exactly when a binding exists.
 *
 * Calls block the caller's thread — never invoke them from the UI thread.
 */
interface ITunnel {
    /** Tear the tunnel down. */
    void stop();

    /** Swap the running config. Returns "" on success, else the failure. */
    String reload(String config);

    double connectedSince();

    /** Which member of a proxy group the engine currently uses, "" if none. */
    String groupMember(String group);

    /**
     * One HTTP probe through the running outbound: "ms:<delay>" or
     * "err:<reason>".
     *
     * Blocks the binder thread for up to `timeoutMs` — the longest call on this
     * interface by far, and the reason the app side hands it to its own
     * executor rather than the UI thread.
     */
    String urlTest(String url, int timeoutMs);

    /** Bytes carried through the outbound this session, "<up>:<down>". */
    String proxyBytes();

    /** Apply the log level to the running engine. */
    void setLogging(boolean enabled);

    void registerCallback(ITunnelCallback cb);
    void unregisterCallback(ITunnelCallback cb);
}
