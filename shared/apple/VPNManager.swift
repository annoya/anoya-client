import Foundation
import NetworkExtension

@MainActor
final class VPNManager {
    static let shared = VPNManager()

    private var tunnelBundleId: String {
        (Bundle.main.bundleIdentifier ?? "") + ".tunnel"
    }
    private let displayName = "VPN"
    private var manager: NETunnelProviderManager?

    var onStatus: ((String) -> Void)?

    @discardableResult
    private func loadOrCreate() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let m = managers.first ?? NETunnelProviderManager()

        let proto = (m.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleId
        proto.serverAddress = displayName
        m.protocolConfiguration = proto
        m.localizedDescription = displayName
        m.isEnabled = true

        try await m.saveToPreferences()
        try await m.loadFromPreferences()

        self.manager = m
        observe(m)
        return m
    }

    private func persist(config: String, logEnabled: Bool,
                         into m: NETunnelProviderManager) async throws {
        guard let proto = m.protocolConfiguration as? NETunnelProviderProtocol else { return }
        let current = proto.providerConfiguration
        let changed = (current?["Config"] as? String) != config
            || (current?["LogEnabled"] as? Bool) != logEnabled
        guard changed else { return }
        proto.providerConfiguration = ["Config": config, "LogEnabled": logEnabled]
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        NSLog("VPN-NATIVE: persisted tunnel config (\(config.count) bytes)")
    }

    func syncConfig(config: String, logEnabled: Bool) async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let m = managers.first else {
            NSLog("VPN-NATIVE: no VPN profile yet, skipping config sync")
            return
        }
        self.manager = m
        observe(m)
        try await persist(config: config, logEnabled: logEnabled, into: m)
    }

    func removeProfile() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard !managers.isEmpty else { return }
        for m in managers {
            m.connection.stopVPNTunnel()
            try await m.removeFromPreferences()
        }
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
            self.statusObserver = nil
        }
        manager = nil
        publish("disconnected", force: true)
        NSLog("VPN-NATIVE: removed VPN profile from system preferences")
    }

    func start(config: String, logEnabled: Bool) async throws {
        let m = try await loadOrCreate()
        NSLog("VPN-NATIVE: loadOrCreate ok, status=\(currentStatus()), enabled=\(m.isEnabled)")
        try await persist(config: config, logEnabled: logEnabled, into: m)

        guard let session = m.connection as? NETunnelProviderSession else {
            throw NSError(domain: "vpn", code: 1, userInfo: [NSLocalizedDescriptionKey: "no tunnel session"])
        }
        let options: [String: NSObject] = [
            "Config": config as NSString,
            "LogEnabled": NSNumber(value: logEnabled),
        ]
        do {
            try session.startTunnel(options: options)
            NSLog("VPN-NATIVE: startTunnel called (config \(config.count) bytes)")
        } catch {
            NSLog("VPN-NATIVE: startTunnel threw: \(error.localizedDescription)")
            throw error
        }
    }

    @discardableResult
    private func adopt() async -> NETunnelProviderManager? {
        if let manager { return manager }
        guard let existing = try? await NETunnelProviderManager.loadAllFromPreferences().first
        else { return nil }
        manager = existing
        observe(existing)
        publish(currentStatus())
        return existing
    }

    private func session(connected: Bool = true) async -> NETunnelProviderSession? {
        guard let m = await adopt(),
              let s = m.connection as? NETunnelProviderSession else { return nil }
        if connected && s.status != .connected { return nil }
        return s
    }

    private var tunnelNotRunning: NSError {
        NSError(domain: "vpn", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "tunnel not running"])
    }

    func refreshStatus() async -> String {
        await adopt()
        return currentStatus()
    }

    func stop() async {
        guard let m = await adopt() else {
            NSLog("VPN-NATIVE: no VPN profile, nothing to stop")
            return
        }
        if m.isOnDemandEnabled {
            m.isOnDemandEnabled = false
            do {
                try await m.saveToPreferences()
                NSLog("VPN-NATIVE: on-demand disarmed for manual stop")
            } catch {
                NSLog("VPN-NATIVE: could not disarm on-demand: \(error.localizedDescription)")
            }
        }
        m.connection.stopVPNTunnel()
    }

    @discardableResult
    func setOnDemand(
        enabled: Bool,
        rules: [[String: Any]],
        disconnectOnSleep: Bool,
        config: String?,
        logEnabled: Bool
    ) async throws -> Bool {
        let m: NETunnelProviderManager
        if enabled {
            m = try await loadOrCreate()
        } else {
            guard let existing = try await NETunnelProviderManager.loadAllFromPreferences().first
            else {
                NSLog("VPN-NATIVE: no VPN profile, nothing to disarm")
                return false
            }
            m = existing
            manager = existing
            observe(existing)
        }
        if let config, !config.isEmpty {
            try await persist(config: config, logEnabled: logEnabled, into: m)
        }
        let compiled = rules.compactMap(compileRule)
        let hasConfig = !((m.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["Config"] as? String ?? "").isEmpty
        let arm = enabled && !compiled.isEmpty && hasConfig

        let wasArmed = m.isOnDemandEnabled
        let ruleChange = !sameRules(m.onDemandRules ?? [], compiled)
        let changed = ruleChange
            || m.isOnDemandEnabled != arm
            || m.protocolConfiguration?.disconnectOnSleep != disconnectOnSleep
        if changed {
            m.onDemandRules = compiled
            m.isOnDemandEnabled = arm
            m.protocolConfiguration?.disconnectOnSleep = disconnectOnSleep
            try await m.saveToPreferences()
            try await m.loadFromPreferences()
        }

        if enabled && !arm {
            NSLog("VPN-NATIVE: on-demand NOT armed (rules=\(compiled.count), config=\(hasConfig))")
        } else if arm != wasArmed {
            NSLog("VPN-NATIVE: on-demand \(arm ? "armed" : "disarmed"), \(compiled.count) rule(s), sleep=\(disconnectOnSleep)")
        }
        return arm
    }

    nonisolated private static let providerMessageTimeout: TimeInterval = 10

    // sendProviderMessage never calls its reply handler if the extension dies.
    private func ask(_ session: NETunnelProviderSession, _ message: String,
                     timeout: TimeInterval = VPNManager.providerMessageTimeout) async throws -> String {
        final class Once: @unchecked Sendable {
            private let lock = NSLock()
            private var done = false
            func claim() -> Bool {
                lock.lock(); defer { lock.unlock() }
                if done { return false }
                done = true
                return true
            }
        }
        let once = Once()
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if once.claim() {
                    cont.resume(throwing: NSError(domain: "vpn", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "the tunnel extension did not respond",
                    ]))
                }
            }
            do {
                try session.sendProviderMessage(Data(message.utf8)) { data in
                    if once.claim() {
                        cont.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) } ?? "")
                    }
                }
            } catch {
                if once.claim() { cont.resume(throwing: error) }
            }
        }
    }

    // NEOnDemandRule is not Equatable.
    private func sameRules(_ a: [NEOnDemandRule], _ b: [NEOnDemandRule]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) {
            if type(of: x) != type(of: y)
                || x.interfaceTypeMatch != y.interfaceTypeMatch
                || x.ssidMatch != y.ssidMatch
                || x.dnsSearchDomainMatch != y.dnsSearchDomainMatch
                || x.dnsServerAddressMatch != y.dnsServerAddressMatch
                || x.probeURL != y.probeURL {
                return false
            }
        }
        return true
    }

    private func compileRule(_ dict: [String: Any]) -> NEOnDemandRule? {
        let rule: NEOnDemandRule
        switch dict["action"] as? String {
        case "connect": rule = NEOnDemandRuleConnect()
        case "disconnect": rule = NEOnDemandRuleDisconnect()
        case "ignore": rule = NEOnDemandRuleIgnore()
        default: return nil
        }
        switch dict["interface"] as? String {
        case "wifi": rule.interfaceTypeMatch = .wiFi
        #if os(iOS)
        case "cellular": rule.interfaceTypeMatch = .cellular
        #elseif os(macOS)
        case "ethernet": rule.interfaceTypeMatch = .ethernet
        #endif
        default: rule.interfaceTypeMatch = .any
        }
        if let ssids = dict["ssids"] as? [String], !ssids.isEmpty {
            rule.ssidMatch = ssids
        }
        if let domains = dict["dns_domains"] as? [String], !domains.isEmpty {
            rule.dnsSearchDomainMatch = domains
        }
        if let servers = dict["dns_servers"] as? [String], !servers.isEmpty {
            rule.dnsServerAddressMatch = servers
        }
        if let probe = dict["probe_url"] as? String, let url = URL(string: probe), !probe.isEmpty {
            rule.probeURL = url
        }
        return rule
    }

    func reload(config: String, logEnabled: Bool) async throws -> String? {
        guard let m = await adopt(),
              let session = m.connection as? NETunnelProviderSession,
              session.status == .connected else { throw tunnelNotRunning }
        let failure = try await ask(session, "reload:\(config)")
        guard failure.isEmpty else {
            throw NSError(domain: "vpn", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: failure])
        }
        NSLog("VPN-NATIVE: hot-reloaded tunnel config (\(config.count) bytes)")
        do {
            try await persist(config: config, logEnabled: logEnabled, into: m)
            return nil
        } catch {
            NSLog("VPN-NATIVE: reload applied but not persisted: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    func setLogging(_ enabled: Bool) async {
        guard let session = await session(connected: false),
              session.status == .connected || session.status == .connecting else { return }
        try? session.sendProviderMessage(Data("logging:\(enabled ? 1 : 0)".utf8)) { _ in }
    }

    private static let logTailBytes = 512 * 1024

    private var logDir: URL {
        get throws {
            guard let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.org.annoya.test") else {
                throw NSError(domain: "vpn", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "no shared container"])
            }
            return group.appendingPathComponent("logs")
        }
    }

    private static let logMaxBytes: UInt64 = 4 * 1024 * 1024

    private static func halveIfOversized(_ file: URL) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? UInt64,
              size > logMaxBytes,
              let handle = try? FileHandle(forUpdating: file) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: size / 2)
        guard let keep = try? handle.readToEnd() else { return }
        try? handle.truncate(atOffset: 0)
        try? handle.seek(toOffset: 0)
        try? handle.write(contentsOf: keep)
    }

    func clearLogs() async throws {
        let dir = try logDir
        for name in ["tunnel", "mihomo"] {
            // Truncate, not unlink: the extension's stdout is freopen'd onto mihomo.log.
            _ = dir.appendingPathComponent("\(name).log").path.withCString { truncate($0, 0) }
        }
    }

    func lastDisconnectError() async -> String {
        guard let m = await adopt() else { return "" }
        guard #available(macOS 13.0, iOS 16.0, *) else { return "" }
        return await withCheckedContinuation { continuation in
            m.connection.fetchLastDisconnectError { error in
                continuation.resume(returning: error?.localizedDescription ?? "")
            }
        }
    }

    func groupMember(_ group: String) async -> String {
        guard let session = await session() else { return "" }
        return (try? await ask(session, "group:\(group)")) ?? ""
    }

    func urlTest(_ url: String, timeoutMs: Int) async throws -> String {
        guard let session = await session() else {
            throw NSError(domain: "vpn", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "the tunnel is not running"])
        }
        return try await ask(session, "urltest:\(timeoutMs):\(url)",
                             timeout: TimeInterval(timeoutMs) / 1000 + 5)
    }

    func proxyBytes() async -> String {
        guard let session = await session() else { return "0:0" }
        return (try? await ask(session, "proxybytes")) ?? "0:0"
    }

    func fetchLog(_ name: String) async throws -> String {
        let file = try logDir.appendingPathComponent("\(name.replacingOccurrences(of: "/", with: "")).log")
        Self.halveIfOversized(file)
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "" }
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let take = UInt64(Self.logTailBytes)
        try handle.seek(toOffset: size > take ? size - take : 0)
        var data = try handle.readToEnd() ?? Data()
        if size > take, let nl = data.firstIndex(of: 0x0a) {
            data = data.suffix(from: data.index(after: nl))
        }
        return String(decoding: data, as: UTF8.self)
    }

    func currentStatus() -> String {
        statusString(manager?.connection.status ?? .invalid)
    }

    func connectedSince() -> Double {
        manager?.connection.connectedDate?.timeIntervalSince1970 ?? 0
    }

    private var statusObserver: NSObjectProtocol?

    private func observe(_ m: NETunnelProviderManager) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
            self.statusObserver = nil
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: m.connection, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.publish(self.currentStatus())
            }
        }
    }

    private func publish(_ status: String, force: Bool = false) {
        guard force || status != lastStatus else { return }
        lastStatus = status
        NSLog("VPN-NATIVE: status changed -> \(status)")
        onStatus?(status)
    }

    private var lastStatus: String?

    private func statusString(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "connected"
        case .connecting, .reasserting: return "connecting"
        // Early "disconnected" makes Dart query a disconnect reason the system has not recorded yet.
        case .disconnecting: return "connecting"
        case .disconnected, .invalid: return "disconnected"
        @unknown default: return "disconnected"
        }
    }
}
