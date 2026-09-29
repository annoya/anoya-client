import NetworkExtension
import MihomoCore

class PacketTunnelProvider: NEPacketTunnelProvider {

    static let appGroup = "group.org.annoya.test"

    // Our own Caches, not the App Group container: the profile's `<TEAM>.*` wildcard
    // does not cover the `group.` id, so the group container is TCC-gated and prompts on every connect.
    private func sharedDir() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private var logEnabled: Bool {
        get { stateLock.withLock { _logEnabled } }
        set { stateLock.withLock { _logEnabled = newValue } }
    }
    private var _logEnabled = true

    private let stateLock = NSLock()

    // Raw POSIX I/O on purpose: Foundation file APIs make a TCC-gated probe that
    // triggers the "access data from other apps" prompt on every connect.
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
            // KVC works on iOS; macOS needs the fd scan.
            var fd = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) ?? -1
            if fd <= 0 { fd = self.tunnelFileDescriptor() ?? -1 }
            guard fd > 0 else {
                self.log("could not obtain tunnel fd")
                completionHandler(self.err("could not obtain tunnel file descriptor"))
                return
            }
            self.log("got tun fd \(fd); starting mihomo")
            self.tunFd = fd
            if self.logEnabled { self.redirectStdoutToMihomoLog() }
            // Set before start too: config parsing logs before the YAML level applies.
            self.applyEngineLogLevel(self.logEnabled)
            if let message = self.startEngine(fd: fd, config: config) {
                // Message not logged: it can quote config lines with uuids and passwords.
                self.log("mihomo start failed")
                self.tunFd = -1 // nothing is running on it; refuse late reloads
                completionHandler(self.err("mihomo start failed: \(message)"))
                return
            }
            // Again after: applying the config overwrites the level from the YAML.
            self.applyEngineLogLevel(self.logEnabled)
            self.log("mihomo started; tunnel up")
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("stopTunnel: reason \(reason.rawValue)")
        // Before MihomoStop, so an in-flight reload cannot restart on a dying fd.
        tunFd = -1
        MihomoStop()
        completionHandler()
    }

    // Must match kTunnelOutbound in mihomo_tun_config.dart.
    private static let tunnelOutbound = "PROXY"

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let request = String(data: messageData, encoding: .utf8) ?? ""
        if request.hasPrefix("reload:") {
            let config = String(request.dropFirst("reload:".count))
            // Read once: a stop between check and use would hand the engine a dead fd.
            let fd = tunFd
            guard fd > 0 else {
                completionHandler?(Data("tunnel has no fd".utf8))
                return
            }
            let failure = reloadEngine(fd: fd, config: config)
            // Reload resets the log level from the YAML.
            applyEngineLogLevel(logEnabled)
            if failure != nil {
                // Message not logged: it can quote the config.
                log("hot reload failed")
            } else {
                log("hot reload applied (\(config.count) bytes)")
            }
            completionHandler?(Data((failure ?? "").utf8))
            return
        }
        if request.hasPrefix("group:") {
            let name = String(request.dropFirst("group:".count))
            let member = name.withCString { ptr -> String in
                guard let res = MihomoGroupMember(UnsafeMutablePointer(mutating: ptr)) else {
                    return ""
                }
                defer { FreeCString(res) }
                return String(cString: res)
            }
            completionHandler?(Data(member.utf8))
            return
        }
        if request == "proxybytes" {
            let answer = Self.tunnelOutbound.withCString { name -> String in
                guard let res = MihomoProxyBytes(UnsafeMutablePointer(mutating: name)) else {
                    return "0:0"
                }
                defer { FreeCString(res) }
                return String(cString: res)
            }
            completionHandler?(Data(answer.utf8))
            return
        }
        if request.hasPrefix("urltest:") {
            // The url goes last: it is the only part that can contain a colon.
            let rest = String(request.dropFirst("urltest:".count))
            let cut = rest.firstIndex(of: ":") ?? rest.startIndex
            let timeout = Int32(rest[rest.startIndex..<cut]) ?? 5000
            let url = String(rest[rest.index(after: cut)...])
            DispatchQueue.global(qos: .userInitiated).async {
                let answer = url.withCString { u -> String in
                    return Self.tunnelOutbound.withCString { name -> String in
                        guard let res = MihomoURLTest(UnsafeMutablePointer(mutating: name),
                                                      UnsafeMutablePointer(mutating: u),
                                                      timeout) else {
                            return "err:the engine did not answer"
                        }
                        defer { FreeCString(res) }
                        return String(cString: res)
                    }
                }
                completionHandler?(Data(answer.utf8))
            }
            return
        }
        if request.hasPrefix("logging:") {
            let on = request.hasSuffix("1")
            logEnabled = on
            if on { redirectStdoutToMihomoLog() }
            // The engine reads log-level only on config apply, so push it directly.
            applyEngineLogLevel(on)
            log("logging \(on ? "enabled" : "disabled") by the app")
            completionHandler?(Data())
            return
        }
        if request == "clear-logs" {
            for name in ["tunnel", "mihomo"] {
                let path = sharedDir().appendingPathComponent("\(name).log").path
                // Truncate, not unlink: stdout is freopen'd onto mihomo.log.
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
        completionHandler?(Data())
    }

    // The iOS extension's memory budget is tens of MB; reading an unbounded log would jetsam it.
    private static let logTailBytes = 512 * 1024
    private static let logMaxBytes = 4 * 1024 * 1024

    private func tailOfLog(named name: String) -> Data {
        let url = sharedDir().appendingPathComponent("\(name).log")
        // mihomo.log is written by Go via stdout and never passes through log(); it is pruned here.
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

    // Keeping half avoids rotating on every line once the cap is reached.
    private static let logKeepFraction = 0.5

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

    // mihomo's default TUN inet6 address (ULA), so interface and stack agree.
    private static let tunnelAddress6 = "fdfe:dcba:9876::1"
    private static let tunnelPrefix6: NSNumber = 126

    // Installed once at start and never re-applied: setTunnelNetworkSettings tears the
    // old settings down first, and routes fall back to the physical interface meanwhile.
    private func applyNetworkSettings(completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: [Self.tunnelAddress6],
                                  networkPrefixLengths: [Self.tunnelPrefix6])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings, completionHandler: completionHandler)
    }

    private func applyEngineLogLevel(_ enabled: Bool) {
        let level = enabled ? "debug" : "silent"
        level.withCString { MihomoSetLogLevel(UnsafeMutablePointer(mutating: $0)) }
    }

    private var stdoutRedirected: Bool {
        get { stateLock.withLock { _stdoutRedirected } }
        set { stateLock.withLock { _stdoutRedirected = newValue } }
    }
    private var _stdoutRedirected = false

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
        setvbuf(stdout, nil, _IOLBF, 0)
        log("mihomo stdout -> \(path)")
    }

    // getsockopt(fd, SYSPROTO_CONTROL = 2, UTUN_OPT_IFNAME = 2)
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

    // Both sides use POSIX-level I/O only here, to stay clear of the Foundation TCC probe.
    private func mihomoHomeDir() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroup) ?? sharedDir()
    }

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
