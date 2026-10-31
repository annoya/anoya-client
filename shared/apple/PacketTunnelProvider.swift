import Network
import NetworkExtension
import MihomoCore
import UserNotifications

class PacketTunnelProvider: NEPacketTunnelProvider {

    static let appGroup = "group.org.annoya.test"

    private static func cachesDir() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private static let logDir: URL = {
        guard let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup) else { return cachesDir() }
        let dir = group.appendingPathComponent("logs")
        _ = dir.path.withCString { mkdir($0, 0o755) }
        return dir
    }()

    private var logEnabled: Bool {
        get { stateLock.withLock { _logEnabled } }
        set { stateLock.withLock { _logEnabled = newValue } }
    }
    private var _logEnabled = true

    private let stateLock = NSLock()

    private static let logPath = logDir.appendingPathComponent("tunnel.log").path

    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // Raw POSIX I/O: Foundation file APIs trigger a TCC prompt on every connect.
    private func log(_ message: String) {
        NSLog("TUNNEL: \(message)")
        guard logEnabled else { return }
        let path = Self.logPath
        let line = "\(Self.stamp.string(from: Date())) \(message)\n"
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
        applyJournal(logEnabled)
        log("startTunnel: begin · pid \(getpid())")
        checkPreviousRun()
        let config = (options?["Config"] as? String)
            ?? TunnelConfigStore.load()
            ?? ""
        startedBySystem = options?["Config"] == nil
        notice = Self.parseNotice((options?["Notice"] as? String) ?? (persisted?["Notice"] as? String))
        guard !config.isEmpty else {
            log("startTunnel: missing config (no options, nothing persisted)")
            noticeStartFailed()
            completionHandler(err("missing tunnel config"))
            return
        }
        if options?["Config"] == nil {
            log("startTunnel: started without the app (on-demand or system settings), using persisted config")
        }
        startNetworkLog()
        startMemoryPressureLog()

        applyNetworkSettings { [weak self] error in
            guard let self else { return }
            if let error {
                self.log("setTunnelNetworkSettings error: \(error.localizedDescription)")
                self.noticeStartFailed()
                completionHandler(error)
                return
            }
            // KVC works on iOS; macOS needs the fd scan.
            var fd = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) ?? -1
            if fd <= 0 { fd = self.tunnelFileDescriptor() ?? -1 }
            guard fd > 0 else {
                self.log("could not obtain tunnel fd")
                self.noticeStartFailed()
                completionHandler(self.err("could not obtain tunnel file descriptor"))
                return
            }
            self.log("got tun fd \(fd); starting mihomo")
            self.tunFd = fd
            if self.logEnabled { self.redirectStdoutToMihomoLog() }
            self.applyCrashLog(self.logEnabled)
            self.applyEngineLogLevel(self.logEnabled)
            if let message = self.startEngine(fd: fd, config: config) {
                self.log("mihomo start failed")
                self.noticeStartFailed()
                self.tunFd = -1
                completionHandler(self.err("mihomo start failed: \(message)"))
                return
            }
            // Applying the config overwrites the log level from the YAML.
            self.applyEngineLogLevel(self.logEnabled)
            self.log("mihomo started; tunnel up · \(Self.memoryFootprint())")
            self.startedAt = Date()
            self.startMemoryLog()
            self.withdraw(Self.startFailedId)
            self.startSilenceWatch()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        let uptime = startedAt.map { " after \(Self.duration(Date().timeIntervalSince($0)))" } ?? ""
        log("stopTunnel: \(Self.stopReasonName(reason)) (\(reason.rawValue))\(uptime) · \(Self.memoryFootprint()) · last network: \(lastPath ?? "unknown")")
        memoryTimer?.cancel()
        memoryTimer = nil
        pressureSource?.cancel()
        pressureSource = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        silenceTimer?.cancel()
        silenceTimer = nil
        withdraw(Self.silentId)
        unlink(Self.runningMarker)
        tunFd = -1
        MihomoStop()
        completionHandler()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        log("sleep · \(Self.memoryFootprint())")
        completionHandler()
    }

    override func wake() {
        log("wake · \(Self.memoryFootprint()) · network: \(lastPath ?? "unknown")")
    }

    private var startedAt: Date? {
        get { stateLock.withLock { _startedAt } }
        set { stateLock.withLock { _startedAt = newValue } }
    }
    private var _startedAt: Date?

    private var pathMonitor: NWPathMonitor?

    private var lastPath: String? {
        get { stateLock.withLock { _lastPath } }
        set { stateLock.withLock { _lastPath = newValue } }
    }
    private var _lastPath: String?

    private func startNetworkLog() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let text = Self.describe(path)
            guard text != self.lastPath else { return }
            self.lastPath = text
            self.log("network: \(text)")
        }
        monitor.start(queue: DispatchQueue(label: "org.annoya.tunnel.path"))
        pathMonitor = monitor
    }

    private static func describe(_ path: Network.NWPath) -> String {
        var parts: [String]
        switch path.status {
        case .satisfied: parts = ["satisfied"]
        case .requiresConnection: parts = ["requires connection"]
        default: parts = ["unsatisfied (\(describe(path.unsatisfiedReason)))"]
        }
        var interfaces: [String] = []
        for interface in path.availableInterfaces where interface.type != .other && interface.type != .loopback {
            let text = "\(interface.name) \(describe(interface.type))"
            if !interfaces.contains(text) { interfaces.append(text) }
        }
        parts.append(interfaces.isEmpty ? "no interfaces" : interfaces.joined(separator: ", "))
        return parts.joined(separator: " · ")
    }

    private static func describe(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "ethernet"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }

    private static func describe(_ reason: Network.NWPath.UnsatisfiedReason) -> String {
        switch reason {
        case .notAvailable: return "no reason given"
        case .cellularDenied: return "cellular denied"
        case .wifiDenied: return "wifi denied"
        case .localNetworkDenied: return "local network denied"
        default: return String(describing: reason)
        }
    }

    private var pressureSource: DispatchSourceMemoryPressure?

    private func startMemoryPressureLog() {
        pressureSource?.cancel()
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let critical = source.data.contains(.critical)
            self.log("memory pressure: \(critical ? "critical" : "warning") · \(Self.memoryFootprint())")
            if critical { MihomoReleaseMemory() }
        }
        source.resume()
        pressureSource = source
    }

    private static let silentId = "anoya.silent"
    private static let startFailedId = "anoya.start_failed"
    private static let serverPickerAction = "server_picker"
    private static let silencePoll = DispatchTimeInterval.seconds(5)

    private var notice: [String: String] {
        get { stateLock.withLock { _notice } }
        set { stateLock.withLock { _notice = newValue } }
    }
    private var _notice: [String: String] = [:]
    private var startedBySystem = false
    private var silenceTimer: DispatchSourceTimer?
    private var silent = false

    private static func parseNotice(_ json: String?) -> [String: String] {
        guard let data = json?.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
        return map
    }

    private func post(_ id: String, title: String?, body: String?, action: String? = nil) {
        guard let title, !title.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? ""
        if let action { content.userInfo = ["action": action] }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil)
        ) { [weak self] error in
            if let error { self?.log("notification not posted: \(error.localizedDescription)") }
        }
    }

    private func withdraw(_ id: String) {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [id])
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func noticeStartFailed() {
        guard startedBySystem else { return }
        let n = notice
        post(Self.startFailedId, title: n["start_failed_title"], body: n["start_failed_body"])
    }

    private func startSilenceWatch() {
        silenceTimer?.cancel()
        silent = false
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + Self.silencePoll, repeating: Self.silencePoll)
        timer.setEventHandler { [weak self] in self?.checkSilence() }
        timer.resume()
        silenceTimer = timer
    }

    private func checkSilence() {
        let now = MihomoServerSilent() != 0
        guard now != silent else { return }
        silent = now
        if now {
            let n = notice
            post(Self.silentId, title: n["silent_title"], body: n["silent_body"], action: Self.serverPickerAction)
            log("told the person: the server is not answering")
        } else {
            withdraw(Self.silentId)
            log("the server answers again; the notice is withdrawn")
        }
    }

    private static let runningMarker = logDir.appendingPathComponent(".tunnel-running").path

    private func checkPreviousRun() {
        if let previous = try? String(contentsOfFile: Self.runningMarker, encoding: .utf8) {
            log("previous extension process (\(previous)) ended without stopTunnel: killed by the system, crashed, or the device restarted")
        }
        let mark = "pid \(getpid()), started \(Self.stamp.string(from: Date()))"
        try? mark.write(toFile: Self.runningMarker, atomically: true, encoding: .utf8)
    }

    private func applyCrashLog(_ enabled: Bool) {
        let path = enabled ? Self.logDir.appendingPathComponent("mihomo.log").path : ""
        path.withCString { MihomoSetCrashLog(UnsafeMutablePointer(mutating: $0)) }
    }

    private func applyJournal(_ enabled: Bool) {
        let path = enabled ? Self.logPath : ""
        path.withCString { MihomoSetJournal(UnsafeMutablePointer(mutating: $0)) }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        if h > 0 { return "\(h)h\(m)m\(s)s" }
        if m > 0 { return "\(m)m\(s)s" }
        return "\(s)s"
    }

    private static let memoryLogInterval = DispatchTimeInterval.seconds(600)

    private var memoryTimer: DispatchSourceTimer?

    private func startMemoryLog() {
        memoryTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + Self.memoryLogInterval, repeating: Self.memoryLogInterval)
        timer.setEventHandler { [weak self] in self?.log("memory: \(Self.memoryFootprint())") }
        timer.resume()
        memoryTimer = timer
    }

    private static func memoryFootprint() -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return "memory unknown" }
        return String(format: "%.1f MB", Double(info.phys_footprint) / 1_048_576)
    }

    private static let stopReasonNames = [
        "none", "userInitiated", "providerFailed", "noNetworkAvailable", "unrecoverableNetworkChange",
        "providerDisabled", "authenticationCanceled", "configurationFailed", "idleTimeout",
        "configurationDisabled", "configurationRemoved", "superceded", "userLogout", "userSwitch",
        "connectionFailed", "sleep", "appUpdate", "internalError",
    ]

    private static func stopReasonName(_ reason: NEProviderStopReason) -> String {
        let raw = reason.rawValue
        return raw >= 0 && raw < stopReasonNames.count ? stopReasonNames[raw] : "unknown"
    }

    private static let tunnelOutbound = "PROXY"

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let request = String(data: messageData, encoding: .utf8) ?? ""
        if request.hasPrefix("reload:") {
            let config = String(request.dropFirst("reload:".count))
            let fd = tunFd
            guard fd > 0 else {
                completionHandler?(Data("tunnel has no fd".utf8))
                return
            }
            let failure = reloadEngine(fd: fd, config: config)
            // Reload overwrites the log level from the YAML.
            applyEngineLogLevel(logEnabled)
            if failure != nil {
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
        if request.hasPrefix("notice:") {
            notice = Self.parseNotice(String(request.dropFirst("notice:".count)))
            completionHandler?(Data())
            return
        }
        if request.hasPrefix("logging:") {
            let on = request.hasSuffix("1")
            logEnabled = on
            if on { redirectStdoutToMihomoLog() }
            applyEngineLogLevel(on)
            applyJournal(on)
            applyCrashLog(on)
            log("logging \(on ? "enabled" : "disabled") by the app")
            completionHandler?(Data())
            return
        }
        completionHandler?(Data())
    }

    private static let logMaxBytes = 4 * 1024 * 1024

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

    private static let tunnelAddress6 = "fdfe:dcba:9876::1"
    private static let tunnelPrefix6: NSNumber = 126

    // Never re-apply: setTunnelNetworkSettings tears routes down first, leaking traffic to the physical interface.
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
        let path = Self.logDir.appendingPathComponent("mihomo.log").path
        freopen(path, "a", stdout)
        setvbuf(stdout, nil, _IOLBF, 0)
        log("mihomo stdout -> \(path)")
    }

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

    private func mihomoHomeDir() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroup) ?? Self.cachesDir()
    }

    private static let jetsamBudget: Int64 = 50 << 20

    private func startEngine(fd: Int32, config: String) -> String? {
        let home = mihomoHomeDir().path
        home.withCString { MihomoSetHomeDir(UnsafeMutablePointer(mutating: $0)) }
        Self.logDir.appendingPathComponent("mihomo.log").path
            .withCString { MihomoSetEngineLog(UnsafeMutablePointer(mutating: $0)) }
        #if os(iOS)
        MihomoSetMemoryBudget(Self.jetsamBudget)
        #endif
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
