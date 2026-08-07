import Foundation
import NetworkExtension

/// VPNManager drives the packet-tunnel extension from the host app via
/// NETunnelProviderManager: it saves/approves the VPN profile, starts the
/// tunnel (passing the mihomo config in the start options), stops it, and
/// reports status changes.
final class VPNManager {
    static let shared = VPNManager()

    // Extension bundle id is the host app's id + ".tunnel" (adapts to whatever
    // bundle id the app is signed with, e.g. com.nt.vpnClient.tunnel).
    private var tunnelBundleId: String {
        (Bundle.main.bundleIdentifier ?? "") + ".tunnel"
    }
    private let displayName = "VPN"
    private var manager: NETunnelProviderManager?

    /// Called on the main queue whenever the tunnel status changes.
    var onStatus: ((String) -> Void)?

    /// Load (or create) the saved VPN configuration. First save triggers the
    /// system approval dialog.
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

    func prepare() async throws {
        _ = try await loadOrCreate()
    }

    /// Write the config into the protocol so an on-demand start (where the OS
    /// launches the extension with no options) has something to run. Only
    /// writes when it actually changed — saving preferences on a live session
    /// makes the system re-assert the tunnel.
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

    /// Keep the persisted config in step with what the app currently has
    /// selected, without starting anything. Deliberately does NOT create the
    /// VPN profile: the first save is what triggers the system approval dialog,
    /// and that belongs to an explicit Connect (or to arming on-demand), not to
    /// merely adding a configuration. With no profile yet there is nothing to
    /// keep in step anyway — the first Connect writes it.
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

    /// Remove the VPN profile from the system entirely — the user deleted the
    /// last configuration, so leaving an entry in System Settings (still able
    /// to auto-start) would be wrong. The next connect recreates it.
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
        lastStatus = nil
        // onStatus feeds a Flutter EventChannel, which must be driven from the
        // platform thread — this runs inside a Task, so hop to main explicitly.
        await MainActor.run { self.onStatus?("disconnected") }
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

    /// Manual stop. When on-demand is armed the system would reconnect within
    /// seconds, so disarm first — the Dart side records this as "paused" and
    /// re-arms on the next connect.
    func stop() async {
        if let m = manager, m.isOnDemandEnabled {
            m.isOnDemandEnabled = false
            try? await m.saveToPreferences()
            NSLog("VPN-NATIVE: on-demand disarmed for manual stop")
        }
        manager?.connection.stopVPNTunnel()
    }

    /// Arm or disarm system on-demand with the given rules, and set the
    /// disconnect-on-sleep flag. Rules come as dictionaries from Dart:
    /// {action, interface, ssids, dns_domains, dns_servers, probe_url}.
    ///
    /// Returns whether on-demand ended up armed. Arming is refused until a
    /// tunnel config has been persisted: the OS would start the extension, the
    /// extension would fail for lack of a config, and the OS would retry
    /// immediately — a connect/disconnect loop several times a second.
    @discardableResult
    func setOnDemand(
        enabled: Bool,
        rules: [[String: Any]],
        disconnectOnSleep: Bool,
        config: String?,
        logEnabled: Bool
    ) async throws -> Bool {
        // Arming may create the profile (the approval dialog belongs to that
        // deliberate action). Disarming must never create one — asking for
        // permission in order to turn something off is nonsense, and it used to
        // happen when the last configuration was deleted.
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
        // Arming needs a config to start from; the caller passes the currently
        // selected one, which also updates the profile in one go.
        if let config, !config.isEmpty {
            try await persist(config: config, logEnabled: logEnabled, into: m)
        }
        let compiled = rules.compactMap(compileRule)
        let hasConfig = !((m.protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["Config"] as? String ?? "").isEmpty
        let arm = enabled && !compiled.isEmpty && hasConfig

        let wasArmed = m.isOnDemandEnabled
        m.onDemandRules = compiled
        m.isOnDemandEnabled = arm
        m.protocolConfiguration?.disconnectOnSleep = disconnectOnSleep
        try await m.saveToPreferences()
        try await m.loadFromPreferences()

        // Only report real transitions: this runs on every connect (to carry
        // the sleep flag), and logging "disarmed" each time is just noise.
        if enabled && !arm {
            NSLog("VPN-NATIVE: on-demand NOT armed (rules=\(compiled.count), config=\(hasConfig))")
        } else if arm != wasArmed {
            NSLog("VPN-NATIVE: on-demand \(arm ? "armed" : "disarmed"), \(compiled.count) rule(s), sleep=\(disconnectOnSleep)")
        }
        return arm
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

    /// Hot-swap the running tunnel onto a new config: the extension applies it
    /// to the engine under the live NE session (same utun fd), so the VPN never
    /// disconnects and the OS routes keep every packet inside the tunnel for
    /// the whole switch. Throws when the tunnel is not up or the engine
    /// rejected the config — in both cases the previous config keeps working.
    func reload(config: String, logEnabled: Bool) async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let m = managers.first,
              let session = m.connection as? NETunnelProviderSession,
              session.status == .connected else {
            throw NSError(domain: "vpn", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "tunnel not running"])
        }
        let request = Data("reload:\(config)".utf8)
        let failure: String = try await withCheckedThrowingContinuation { cont in
            do {
                try session.sendProviderMessage(request) { data in
                    cont.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) } ?? "")
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
        guard failure.isEmpty else {
            throw NSError(domain: "vpn", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: failure])
        }
        self.manager = m
        observe(m)
        // The persisted copy is what an on-demand restart (or the next manual
        // start) runs — keep it in step with what the engine now runs.
        try await persist(config: config, logEnabled: logEnabled, into: m)
        NSLog("VPN-NATIVE: hot-reloaded tunnel config (\(config.count) bytes)")
    }

    /// Tell the running extension whether to keep writing logs. The engine's
    /// level lives in the applied config, so a live tunnel has to be told
    /// directly; with the tunnel down there is nothing to tell — the persisted
    /// config already carries the flag for the next start.
    func setLogging(_ enabled: Bool) async {
        let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
        guard let session = managers?.first?.connection as? NETunnelProviderSession,
              session.status == .connected || session.status == .connecting else { return }
        try? session.sendProviderMessage(Data("logging:\(enabled ? 1 : 0)".utf8)) { _ in }
    }

    /// Ask the running extension to delete its log files. Like fetchLog, this
    /// only works while the tunnel is up: the extension is the only process
    /// that may touch its own container.
    func clearLogs() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let session = managers.first?.connection as? NETunnelProviderSession else {
            throw NSError(domain: "vpn", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "tunnel not running"])
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                try session.sendProviderMessage(Data("clear-logs".utf8)) { _ in
                    cont.resume()
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    /// Ask the running extension for one of its log files (e.g. "tunnel",
    /// "mihomo") over the provider IPC channel. Only works while the tunnel is
    /// up; throws otherwise (the extension process is the log's only reader,
    /// since it lives in the extension's own sandbox container).
    func fetchLog(_ name: String) async throws -> String {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let session = managers.first?.connection as? NETunnelProviderSession else {
            throw NSError(domain: "vpn", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "tunnel not running"])
        }
        let request = Data("log:\(name)".utf8)
        return try await withCheckedThrowingContinuation { cont in
            do {
                try session.sendProviderMessage(request) { data in
                    cont.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) } ?? "")
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    func currentStatus() -> String {
        statusString(manager?.connection.status ?? .invalid)
    }

    /// Block-based observers are identified by the token addObserver returns —
    /// removeObserver(self,…) does NOT remove them. Keeping the token is what
    /// stops every loadOrCreate() from stacking another observer (which is why
    /// one status change used to be reported a dozen times).
    private var statusObserver: NSObjectProtocol?

    private func observe(_ m: NETunnelProviderManager) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
            self.statusObserver = nil
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: m.connection, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let status = self.currentStatus()
            guard status != self.lastStatus else { return }
            self.lastStatus = status
            NSLog("VPN-NATIVE: status changed -> \(status)")
            self.onStatus?(status)
        }
    }

    private var lastStatus: String?

    private func statusString(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "connected"
        case .connecting, .reasserting: return "connecting"
        case .disconnecting: return "connecting"
        case .disconnected, .invalid: return "disconnected"
        @unknown default: return "disconnected"
        }
    }
}
