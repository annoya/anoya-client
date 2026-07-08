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

    func start(config: String, serverIp: String?) async throws {
        let m = try await loadOrCreate()
        NSLog("VPN-NATIVE: loadOrCreate ok, status=\(currentStatus()), enabled=\(m.isEnabled)")
        guard let session = m.connection as? NETunnelProviderSession else {
            throw NSError(domain: "vpn", code: 1, userInfo: [NSLocalizedDescriptionKey: "no tunnel session"])
        }
        var options: [String: NSObject] = ["Config": config as NSString]
        if let serverIp, !serverIp.isEmpty {
            options["ServerIP"] = serverIp as NSString
        }
        do {
            try session.startTunnel(options: options)
            NSLog("VPN-NATIVE: startTunnel called (config \(config.count) bytes, server \(serverIp ?? "-"))")
        } catch {
            NSLog("VPN-NATIVE: startTunnel threw: \(error.localizedDescription)")
            throw error
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
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

    private func observe(_ m: NETunnelProviderManager) {
        NotificationCenter.default.removeObserver(self, name: .NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: m.connection, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            NSLog("VPN-NATIVE: status changed -> \(self.currentStatus())")
            self.onStatus?(self.currentStatus())
        }
    }

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
