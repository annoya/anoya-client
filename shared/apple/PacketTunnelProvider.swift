import NetworkExtension
import MihomoCore

// MihomoCore.xcframework exposes the C API:
//   char* MihomoStart(int fd, char* configJSON);  // "" on success, else error
//   void  MihomoStop(void);
//   char* MihomoVersion(void);
//   void  FreeCString(char* s);

/// PacketTunnelProvider runs the mihomo engine inside the Network Extension.
/// Flow: receive the mihomo config in the start options, configure the system
/// tunnel (addresses/routes/DNS), grab the utun file descriptor, hand it to
/// mihomo. Same code path on macOS and iOS.
class PacketTunnelProvider: NEPacketTunnelProvider {

    static let appGroup = "group.org.annoya.test"

    /// Directory the extension writes its logs to.
    ///
    /// Deliberately the extension's OWN sandbox container (Caches), NOT the App
    /// Group container: accessing the group container is TCC-gated unless the
    /// group is explicitly authorized by the provisioning profile (ours only
    /// carries the team wildcard `<TEAM>.*`, which does not cover the
    /// `group.`-style id), which triggers the "access data from other apps"
    /// prompt on every connect. The host reads these logs over the provider
    /// IPC channel (handleAppMessage) instead of from a shared container.
    private func sharedDir() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// Log to NSLog (visible via `log stream`) and to tunnel.log in the shared
    /// container so the host app can read it directly.
    ///
    /// Uses raw POSIX open/write rather than NSFileHandle/NSURL: the high-level
    /// Foundation file APIs perform a side TCC-gated probe (resource values /
    /// xattrs) on the file that triggers the macOS "access data from other
    /// apps" prompt on every connect, even though the App Group container is
    /// already accessible via the sandbox entitlement. POSIX I/O (like the
    /// freopen below) does not, so it stays silent.
    /// Mirrors the app's "Collect logs" switch, carried in the start options and
    /// in providerConfiguration (an on-demand start has no options). Off means
    /// the file stops growing; what is already in it stays.
    private var logEnabled: Bool {
        get { stateLock.withLock { _logEnabled } }
        set { stateLock.withLock { _logEnabled = newValue } }
    }
    private var _logEnabled = true

    /// startTunnel's settings callback and handleAppMessage run on different
    /// threads and both touch the three fields below, so they are read and
    /// written under this lock. The interesting one is tunFd: a stop racing an
    /// in-flight reload decides whether the engine gets restarted on a dead
    /// descriptor.
    private let stateLock = NSLock()

    private func log(_ message: String) {
        NSLog("TUNNEL: \(message)")
        guard logEnabled else { return }
        let path = sharedDir().appendingPathComponent("tunnel.log").path
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        rotateIfNeeded(path)
        let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return }
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress { _ = write(fd, base, raw.count) }
        }
        close(fd)
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // The app passes the config in the start options. On-demand starts come
        // from the OS with no options — fall back to the copy the app persisted
        // in providerConfiguration on its last connect. Same for the log switch.
        let persisted = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration
        logEnabled = (options?["LogEnabled"] as? NSNumber)?.boolValue
            ?? (persisted?["LogEnabled"] as? Bool)
            ?? true
        log("startTunnel: begin")
        let config = (options?["Config"] as? String)
            ?? (persisted?["Config"] as? String)
            ?? ""
        guard !config.isEmpty else {
            log("startTunnel: missing config (no options, nothing persisted)")
            completionHandler(err("missing tunnel config"))
            return
        }
        if options?["Config"] == nil { log("startTunnel: on-demand start, using persisted config") }

        applyNetworkSettings { [weak self] error in
            guard let self else { return }
            if let error {
                self.log("setTunnelNetworkSettings error: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            // KVC trick works on iOS; on macOS fall back to scanning fds for
            // the utun interface (WireGuard-style).
            var fd = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) ?? -1
            if fd <= 0 { fd = self.tunnelFileDescriptor() ?? -1 }
            guard fd > 0 else {
                self.log("could not obtain tunnel fd")
                completionHandler(self.err("could not obtain tunnel file descriptor"))
                return
            }
            self.log("got tun fd \(fd); starting mihomo")
            self.tunFd = fd
            // Only wire up the engine's log file when we are collecting: with
            // the switch off the file should not even appear.
            if self.logEnabled { self.redirectStdoutToMihomoLog() }
            // Before the start: parsing the config already logs (geo rule
            // loading, "initial configuration in progress"), and that happens
            // before the engine applies the level from the YAML.
            self.applyEngineLogLevel(self.logEnabled)
            if let message = self.startEngine(fd: fd, config: config) {
                // Not into the log: engine errors quote the offending config
                // line, and config lines carry uuids and passwords. The app
                // gets the detail through the start error, which it shows in a
                // dialog and does not archive.
                self.log("mihomo start failed")
                self.tunFd = -1 // nothing is running on it; refuse late reloads
                completionHandler(self.err("mihomo start failed: \(message)"))
                return
            }
            // And again after: applying the config overwrites the level with
            // whatever the YAML said, which may be stale.
            self.applyEngineLogLevel(self.logEnabled)
            self.log("mihomo started; tunnel up")
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("stopTunnel: reason \(reason.rawValue)")
        // Before the stop: a reload message already in flight would otherwise
        // still see a live fd and restart the engine on a descriptor the system
        // is tearing down.
        tunFd = -1
        MihomoStop()
        completionHandler()
    }

    /// IPC from the host app. Protocol: a UTF-8 request string.
    ///   "log:<name>"      -> returns the bytes of <name>.log from our container
    ///   "clear-logs"      -> empties our log files
    ///   "reload:<yaml>"   -> hot-swaps the engine onto a new config (same fd,
    ///                        same network settings, session stays up)
    ///   "logging:<0|1>"   -> turns log writing off/on without reconnecting
    /// The host uses this to display tunnel/core logs without a shared
    /// container (which would be TCC-gated). Reading our OWN container is never
    /// TCC-gated. Only works while the tunnel is running (extension alive).
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let request = String(data: messageData, encoding: .utf8) ?? ""
        if request.hasPrefix("reload:") {
            let config = String(request.dropFirst("reload:".count))
            // One read, then use that value: checking the property and reading
            // it again would let a stop in between hand the engine an fd this
            // very guard just rejected.
            let fd = tunFd
            guard fd > 0 else {
                completionHandler?(Data("tunnel has no fd".utf8))
                return
            }
            // The network settings stay exactly as installed at start: the engine
            // reaches the new server on its own (see applyNetworkSettings).
            let failure = reloadEngine(fd: fd, config: config)
            // ApplyConfig resets the log level from the YAML; keep the runtime
            // switch the last word, same as on start.
            applyEngineLogLevel(logEnabled)
            if failure != nil {
                // Same reason as at start: the engine's message can quote the
                // config. The app receives it below and shows it once.
                log("hot reload failed")
            } else {
                log("hot reload applied (\(config.count) bytes)")
            }
            completionHandler?(Data((failure ?? "").utf8))
            return
        }
        if request.hasPrefix("logging:") {
            let on = request.hasSuffix("1")
            logEnabled = on
            // Turning it on mid-session: the engine's stdout may never have been
            // redirected, so there would be nowhere for its log to land.
            if on { redirectStdoutToMihomoLog() }
            // The engine reads log-level only when a config is applied, so a
            // running tunnel needs the level pushed in directly — otherwise it
            // would keep filling mihomo.log until the next connect.
            applyEngineLogLevel(on)
            log("logging \(on ? "enabled" : "disabled") by the app")
            completionHandler?(Data())
            return
        }
        if request == "clear-logs" {
            for name in ["tunnel", "mihomo"] {
                let path = sharedDir().appendingPathComponent("\(name).log").path
                // Truncate rather than unlink: mihomo's stdout is freopen'd onto
                // mihomo.log, and removing the file would leave it writing to a
                // deleted inode with no way to reopen it.
                _ = path.withCString { truncate($0, 0) }
            }
            completionHandler?(Data())
            return
        }
        if request.hasPrefix("log:") {
            let name = String(request.dropFirst(4)).replacingOccurrences(of: "/", with: "")
            completionHandler?(tailOfLog(named: name))
            return
        }
        // Unknown request: an empty reply, never an echo. Only the host app can
        // reach this channel, so this is about being strict, not defensive.
        completionHandler?(Data())
    }

    /// Largest log slice we read into memory, and the size a log file is
    /// allowed to reach before it is halved. The iOS extension's whole memory
    /// budget is tens of megabytes, so reading an unbounded log to answer the
    /// app would jetsam the extension — killing the VPN because someone opened
    /// the Logs screen.
    private static let logTailBytes = 512 * 1024
    private static let logMaxBytes = 4 * 1024 * 1024

    /// The last [logTailBytes] of a log file, cut at a line boundary.
    private func tailOfLog(named name: String) -> Data {
        let url = sharedDir().appendingPathComponent("\(name).log")
        // The engine's own log is written by Go through a freopen'd stdout, so
        // it never passes through log(); this is where it gets pruned. Append
        // mode means the engine keeps writing correctly across the truncation.
        rotateIfNeeded(url.path)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let take = UInt64(Self.logTailBytes)
        if size > take {
            try? handle.seek(toOffset: size - take)
        } else {
            try? handle.seek(toOffset: 0)
        }
        guard var data = try? handle.readToEnd() else { return Data() }
        if size > take, let nl = data.firstIndex(of: 0x0a) {
            data = data.suffix(from: data.index(after: nl))
        }
        return data
    }

    /// How much of a log survives a rotation. Keeping half means a rotation
    /// happens once per half-cap of writing rather than on every line once the
    /// cap is reached, which is what a "trim to exactly the cap" rule would do.
    private static let logKeepFraction = 0.5

    /// Trim a log that has grown past the cap, keeping the newest part. Called
    /// on write; nothing else prunes these files (the app's "clear logs" is
    /// manual), so without this a long-running tunnel grows one without bound.
    private func rotateIfNeeded(_ path: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64, size > UInt64(Self.logMaxBytes) else { return }
        guard let handle = try? FileHandle(forUpdating: URL(fileURLWithPath: path)) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: UInt64(Double(size) * (1 - Self.logKeepFraction)))
        guard let keep = try? handle.readToEnd() else { return }
        try? handle.truncate(atOffset: 0)
        try? handle.seek(toOffset: 0)
        try? handle.write(contentsOf: keep)
    }

    /// The tunnel interface's own IPv6 address. The value is the engine's
    /// documented default for its TUN stack, so the interface and the stack
    /// running on it agree on one address instead of two invented ones; it is
    /// ULA space (RFC 4193), which is what an address that must never appear
    /// on the wire should be. What matters is that it is fixed: it is part of
    /// the settings installed once at start and never re-applied.
    private static let tunnelAddress6 = "fdfe:dcba:9876::1"
    private static let tunnelPrefix6: NSNumber = 126

    /// The tunnel's network settings, installed once at start and never touched
    /// again — a hot switch must not go near them, because
    /// setTunnelNetworkSettings tears the current settings down before it
    /// installs the new ones, and in that window the OS routes fall back to the
    /// physical interface: a burst of real leaks on every switch.
    ///
    /// Nothing is excluded from the tunnel, not even the proxy server. The engine
    /// binds its own dials to the physical interface (IP_BOUND_IF), so its
    /// connection to the server leaves regardless of where the routes point,
    /// while every other address — including servers we are not using — stays
    /// inside. If that binding ever failed the tunnel would go silent instead of
    /// leaking, which is the right direction to fail in.
    private func applyNetworkSettings(completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 9000

        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // IPv6 is carried, not merely claimed: the engine runs with ipv6 on and
        // its own v6 fake-IP pool, so AAAA answers resolve and v6 destinations
        // are proxied like v4 ones. Without these settings the OS would keep
        // the physical interface's v6 default route and everything reaching a
        // v6 address — a literal address, or an AAAA an app resolved over its
        // own DoH past the :53 hijack — would leave in the clear. Cellular is
        // v6-primary, so that is the common case, not the exotic one.
        let ipv6 = NEIPv6Settings(addresses: [Self.tunnelAddress6],
                                  networkPrefixLengths: [Self.tunnelPrefix6])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings, completionHandler: completionHandler)
    }

    /// Push the log level into the running engine: "info" while collecting,
    /// "silent" when the user turned logging off.
    private func applyEngineLogLevel(_ enabled: Bool) {
        let level = enabled ? "info" : "silent"
        level.withCString { MihomoSetLogLevel(UnsafeMutablePointer(mutating: $0)) }
    }

    /// mihomo logs to stdout; redirect it to a file in the extension's
    /// container so we can read what the engine is doing (dials, DNS, etc.):
    ///   ~/Library/Containers/<ext-id>/Data/Library/Caches/mihomo.log
    private var stdoutRedirected: Bool {
        get { stateLock.withLock { _stdoutRedirected } }
        set { stateLock.withLock { _stdoutRedirected = newValue } }
    }
    private var _stdoutRedirected = false

    /// The utun fd the engine runs on, kept for hot reloads: a new config is
    /// applied onto the same fd, so the NE session never notices the swap.
    private var tunFd: Int32 {
        get { stateLock.withLock { _tunFd } }
        set { stateLock.withLock { _tunFd = newValue } }
    }
    private var _tunFd: Int32 = -1

    private func redirectStdoutToMihomoLog() {
        guard !stdoutRedirected else { return }
        stdoutRedirected = true
        let path = sharedDir().appendingPathComponent("mihomo.log").path
        freopen(path, "a", stdout)
        setvbuf(stdout, nil, _IOLBF, 0) // line-buffered for prompt logs
        log("mihomo stdout -> \(path)")
    }

    /// Find the utun file descriptor backing this tunnel by scanning open fds
    /// for the one whose SYSPROTO_CONTROL interface name starts with "utun".
    /// (SYSPROTO_CONTROL = 2, UTUN_OPT_IFNAME = 2.)
    private func tunnelFileDescriptor() -> Int32? {
        var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        for fd in (0 as Int32)..<1024 {
            var len = socklen_t(buf.count)
            if getsockopt(fd, 2, 2, &buf, &len) == 0, String(cString: buf).hasPrefix("utun") {
                return fd
            }
        }
        return nil
    }

    /// mihomo's working directory: the App Group container, where the host app
    /// downloads the GeoIP/GeoSite databases (geoip.metadb, GeoSite.dat). Both
    /// sides touch it with POSIX-level I/O only (Go file ops / dart:io), which
    /// stays clear of the Foundation TCC probe (see log() above). Falls back to
    /// our own Caches when the group container is unavailable.
    private func mihomoHomeDir() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroup) ?? sharedDir()
    }

    /// Calls into the Go core. Returns nil on success or an error message.
    private func startEngine(fd: Int32, config: String) -> String? {
        let home = mihomoHomeDir().path
        home.withCString { MihomoSetHomeDir(UnsafeMutablePointer(mutating: $0)) }
        log("mihomo home dir: \(home)")
        return config.withCString { cfgPtr -> String? in
            guard let res = MihomoStart(fd, UnsafeMutablePointer(mutating: cfgPtr)) else {
                return nil
            }
            defer { FreeCString(res) }
            let message = String(cString: res)
            return message.isEmpty ? nil : message
        }
    }

    /// Hot reload: same contract as startEngine — nil on success. On failure
    /// the engine keeps running on the previous config, so the tunnel is fine.
    private func reloadEngine(fd: Int32, config: String) -> String? {
        config.withCString { cfgPtr -> String? in
            guard let res = MihomoReload(fd, UnsafeMutablePointer(mutating: cfgPtr)) else {
                return nil
            }
            defer { FreeCString(res) }
            let message = String(cString: res)
            return message.isEmpty ? nil : message
        }
    }

    private func err(_ message: String) -> NSError {
        NSError(domain: "org.annoya.test.tunnel", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
