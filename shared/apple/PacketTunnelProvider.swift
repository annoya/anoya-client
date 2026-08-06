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

    static let appGroup = "group.com.nt.vpnClient"

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
    private var logEnabled = true

    private func log(_ message: String) {
        NSLog("TUNNEL: \(message)")
        guard logEnabled else { return }
        let path = sharedDir().appendingPathComponent("tunnel.log").path
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
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

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 9000

        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        // Exclude the VPN server itself so mihomo's own connection to the worker
        // bypasses the tunnel (otherwise it loops back into the utun → no traffic).
        let serverIP = (options?["ServerIP"] as? String) ?? (persisted?["ServerIP"] as? String) ?? ""
        if !serverIP.isEmpty {
            ipv4.excludedRoutes = [NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255")]
            log("excluding server route \(serverIP)")
        }
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings) { [weak self] error in
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
            // Only wire up the engine's log file when we are collecting: with
            // the switch off the file should not even appear.
            if self.logEnabled { self.redirectStdoutToMihomoLog() }
            // Before the start: parsing the config already logs (geo rule
            // loading, "initial configuration in progress"), and that happens
            // before the engine applies the level from the YAML.
            self.applyEngineLogLevel(self.logEnabled)
            if let message = self.startEngine(fd: fd, config: config) {
                self.log("mihomo start failed: \(message)")
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
        MihomoStop()
        completionHandler()
    }

    /// IPC from the host app. Protocol: a UTF-8 request string.
    ///   "log:<name>"      -> returns the bytes of <name>.log from our container
    ///   "clear-logs"      -> empties our log files
    ///   "logging:<0|1>"   -> turns log writing off/on without reconnecting
    /// The host uses this to display tunnel/core logs without a shared
    /// container (which would be TCC-gated). Reading our OWN container is never
    /// TCC-gated. Only works while the tunnel is running (extension alive).
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let request = String(data: messageData, encoding: .utf8) ?? ""
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
            let url = sharedDir().appendingPathComponent("\(name).log")
            completionHandler?((try? Data(contentsOf: url)) ?? Data())
            return
        }
        completionHandler?(messageData)
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
    private var stdoutRedirected = false

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

    private func err(_ message: String) -> NSError {
        NSError(domain: "com.example.vpnClient.tunnel", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
