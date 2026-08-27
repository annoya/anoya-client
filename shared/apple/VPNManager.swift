import Foundation
import NetworkExtension

/// VPNManager drives the packet-tunnel extension from the host app via
/// NETunnelProviderManager: it saves/approves the VPN profile, starts the
/// tunnel (passing the mihomo config in the start options), stops it, and
/// reports status changes.
final class VPNManager {
    static let shared = VPNManager()

    // Extension bundle id is the host app's id + ".tunnel" (adapts to whatever
    // bundle id the app is signed with, e.g. org.annoya.test.tunnel).
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
        // Forced: the last published status may already be "disconnected" (the
        // profile can be removed while the tunnel is down), and the Dart side
        // still has to hear that there is no profile any more.
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

    /// Adopts the VPN profile the system already holds, if any, without
    /// creating one. The app process is not the tunnel's owner — it quits on
    /// window close (macOS) or gets killed while the extension keeps running —
    /// so on a fresh launch over a live tunnel `manager` is nil and anything
    /// reading it sees "no VPN". Every entry point that must reflect reality
    /// goes through here first.
    @discardableResult
    private func adopt() async -> NETunnelProviderManager? {
        if let manager { return manager }
        guard let existing = try? await NETunnelProviderManager.loadAllFromPreferences().first
        else { return nil }
        manager = existing
        observe(existing)
        // The status the app was told at launch predates this; publish the real
        // one now that there is something to read it from.
        publish(currentStatus())
        return existing
    }

    /// The tunnel's current state. Loads the system's profile when the app has
    /// not touched it yet, so a relaunch over a live tunnel does not report
    /// "disconnected".
    func refreshStatus() async -> String {
        await adopt()
        return currentStatus()
    }

    /// Manual stop. When on-demand is armed the system would reconnect within
    /// seconds, so disarm first — the Dart side records this as "paused" and
    /// re-arms on the next connect.
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
                // Stopping without disarming means the system reconnects within
                // seconds and the user's manual disconnect silently loses.
                NSLog("VPN-NATIVE: could not disarm on-demand: \(error.localizedDescription)")
            }
        }
        m.connection.stopVPNTunnel()
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
        // Same constraint persist() respects: saving preferences on a live
        // session makes the system re-assert the tunnel. This runs on every
        // connect and on every rules edit, so save only on a real change —
        // otherwise editing a rule name while connected flaps the session.
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

        // Only report real transitions: this runs on every connect (to carry
        // the sleep flag), and logging "disarmed" each time is just noise.
        if enabled && !arm {
            NSLog("VPN-NATIVE: on-demand NOT armed (rules=\(compiled.count), config=\(hasConfig))")
        } else if arm != wasArmed {
            NSLog("VPN-NATIVE: on-demand \(arm ? "armed" : "disarmed"), \(compiled.count) rule(s), sleep=\(disconnectOnSleep)")
        }
        return arm
    }

    /// How long the extension gets to answer a provider message. Applying a
    /// config is the slow one (parsing plus a full engine reload) and is well
    /// under a second in practice; this is a deadline for a process that has
    /// stopped answering, not a performance budget.
    private static let providerMessageTimeout: TimeInterval = 10

    /// One provider-IPC round trip, with a deadline.
    ///
    /// sendProviderMessage's reply handler is simply never called if the
    /// extension dies before answering (a panic inside the engine while
    /// applying a config, a jetsam). Without a deadline the continuation is
    /// never resumed and the caller — a hot switch, a log fetch — hangs the UI
    /// forever with no error to show.
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

    /// NEOnDemandRule is not Equatable, so compare the fields we actually set.
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
        let failure = try await ask(session, "reload:\(config)")
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
        _ = try await ask(session, "clear-logs")
    }

    /// Ask the running extension for one of its log files (e.g. "tunnel",
    /// "mihomo") over the provider IPC channel. Only works while the tunnel is
    /// up; throws otherwise (the extension process is the log's only reader,
    /// since it lives in the extension's own sandbox container).
    /// Why the tunnel stopped, when the system knows.
    ///
    /// A packet-tunnel provider that fails inside `startTunnel` reports it to
    /// the *system*, not to us: the app sees the status go connecting →
    /// disconnected and nothing else, which is why an engine that refuses a
    /// config looked like a connect that ran forever and then gave up. This is
    /// the one API that hands that reason back.
    ///
    /// Empty when the platform is too old to have it (macOS 13 / iOS 16), when
    /// the stop was ordinary, or when the system kept no reason — a killed
    /// extension (memory) is one of those.
    func lastDisconnectError() async -> String {
        guard let m = await adopt() else { return "" }
        guard #available(macOS 13.0, iOS 16.0, *) else { return "" }
        return await withCheckedContinuation { continuation in
            m.connection.fetchLastDisconnectError { error in
                continuation.resume(returning: error?.localizedDescription ?? "")
            }
        }
    }

    /// Which member of a proxy group the engine is currently using, or "" when
    /// there is no running tunnel or no such group.
    ///
    /// Never throws: this feeds a subtitle, and a missing answer means "not
    /// known yet", which the app shows as plain "auto" rather than an error.
    func groupMember(_ group: String) async -> String {
        let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
        guard let session = managers?.first?.connection as? NETunnelProviderSession,
              session.status == .connected else { return "" }
        return (try? await ask(session, "group:\(group)")) ?? ""
    }

    func fetchLog(_ name: String) async throws -> String {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let session = managers.first?.connection as? NETunnelProviderSession else {
            throw NSError(domain: "vpn", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "tunnel not running"])
        }
        return try await ask(session, "log:\(name)")
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
            self.publish(self.currentStatus())
        }
    }

    /// Publishes a status change to the Flutter side, from the main thread and
    /// nowhere else.
    ///
    /// [onStatus] feeds a Flutter EventChannel, and platform-channel messages
    /// must be sent on the platform thread — Flutter warns that a send from
    /// anywhere else may lose the message or crash. Getting that wrong is easy
    /// here: this class is not actor-isolated, so a `nonisolated async` method
    /// like [adopt] runs on the cooperative pool even when its caller started
    /// on `@MainActor`. Every publication goes through this one door instead of
    /// each call site remembering to hop.
    ///
    /// The dedup lives on the far side of the hop so [lastStatus] is only ever
    /// touched on the main thread.
    private func publish(_ status: String, force: Bool = false) {
        if Thread.isMainThread {
            deliver(status, force: force)
        } else {
            DispatchQueue.main.async { [weak self] in self?.deliver(status, force: force) }
        }
    }

    private func deliver(_ status: String, force: Bool) {
        guard force || status != lastStatus else { return }
        lastStatus = status
        NSLog("VPN-NATIVE: status changed -> \(status)")
        onStatus?(status)
    }

    /// Last status handed to Dart. Main thread only — see [publish].
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
