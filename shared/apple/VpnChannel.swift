#if canImport(FlutterMacOS)
import FlutterMacOS
#else
import Flutter
#endif
import Foundation
import Libagw

enum VpnChannel {
    static func register(messenger: FlutterBinaryMessenger) {
        let control = FlutterMethodChannel(name: "vpn/control", binaryMessenger: messenger)
        control.setMethodCallHandler { call, result in
            switch call.method {
            case "start":
                let args = call.arguments as? [String: Any]
                guard let config = args?["config"] as? String else {
                    result(FlutterError(code: "bad_args", message: "config required", details: nil))
                    return
                }
                let logEnabled = args?["log_enabled"] as? Bool ?? true
                Task { @MainActor in
                    do {
                        try await VPNManager.shared.start(config: config, logEnabled: logEnabled)
                        result(nil)
                    }
                    catch { result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil)) }
                }
            case "stop":
                Task { @MainActor in
                    await VPNManager.shared.stop()
                    result(nil)
                }
            case "set_on_demand":
                let args = call.arguments as? [String: Any] ?? [:]
                let enabled = args["enabled"] as? Bool ?? false
                let rules = args["rules"] as? [[String: Any]] ?? []
                let sleep = args["disconnect_on_sleep"] as? Bool ?? false
                Task { @MainActor in
                    do {
                        let armed = try await VPNManager.shared.setOnDemand(
                            enabled: enabled, rules: rules, disconnectOnSleep: sleep,
                            config: args["config"] as? String,
                            logEnabled: args["log_enabled"] as? Bool ?? true)
                        result(armed)
                    } catch {
                        result(FlutterError(code: "on_demand_failed",
                                            message: error.localizedDescription, details: nil))
                    }
                }
            case "reload":
                let args = call.arguments as? [String: Any] ?? [:]
                guard let config = args["config"] as? String else {
                    result(FlutterError(code: "bad_args", message: "config required", details: nil))
                    return
                }
                Task { @MainActor in
                    do {
                        try await VPNManager.shared.reload(
                            config: config, logEnabled: args["log_enabled"] as? Bool ?? true)
                        result(nil)
                    } catch {
                        result(FlutterError(code: "reload_failed",
                                            message: error.localizedDescription, details: nil))
                    }
                }
            case "sync_config":
                let args = call.arguments as? [String: Any] ?? [:]
                guard let config = args["config"] as? String else {
                    result(FlutterError(code: "bad_args", message: "config required", details: nil))
                    return
                }
                Task { @MainActor in
                    do {
                        try await VPNManager.shared.syncConfig(
                            config: config, logEnabled: args["log_enabled"] as? Bool ?? true)
                        result(nil)
                    } catch {
                        result(FlutterError(code: "sync_failed",
                                            message: error.localizedDescription, details: nil))
                    }
                }
            case "remove_profile":
                Task { @MainActor in
                    do { try await VPNManager.shared.removeProfile(); result(nil) }
                    catch { result(FlutterError(code: "remove_failed",
                                                message: error.localizedDescription, details: nil)) }
                }
            case "connected_since":
                Task { @MainActor in result(VPNManager.shared.connectedSince()) }
            case "disconnect_error":
                Task { @MainActor in result(await VPNManager.shared.lastDisconnectError()) }
            case "group_member":
                let name = (call.arguments as? [String: Any])?["group"] as? String ?? ""
                Task { @MainActor in result(await VPNManager.shared.groupMember(name)) }
            case "proxy_bytes":
                Task { @MainActor in result(await VPNManager.shared.proxyBytes()) }
            case "url_test":
                let args = call.arguments as? [String: Any]
                let url = args?["url"] as? String ?? ""
                let timeout = args?["timeout_ms"] as? Int ?? 5000
                Task { @MainActor in
                    do {
                        result(try await VPNManager.shared.urlTest(url, timeoutMs: timeout))
                    } catch {
                        result(FlutterError(code: "url_test",
                                            message: error.localizedDescription, details: nil))
                    }
                }
            case "device_info":
                result(deviceInfo())
            case "gateway_abi":
                // Keeps the linker from dropping the Libagw archive, otherwise only used via Dart FFI.
                result(Int(agw_abi_version()))
            case "shared_dir":
                let url = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.org.annoya.test")
                result(url?.path)
            case "set_logging":
                let on = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? true
                Task { @MainActor in
                    await VPNManager.shared.setLogging(on)
                    result(nil)
                }
            case "clear_logs":
                Task { @MainActor in
                    do { try await VPNManager.shared.clearLogs(); result(nil) }
                    catch { result(FlutterError(code: "clear_logs_failed",
                                                message: error.localizedDescription, details: nil)) }
                }
            case "fetch_log":
                let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
                Task { @MainActor in
                    do { let text = try await VPNManager.shared.fetchLog(name); result(text) }
                    catch { result(FlutterError(code: "fetch_log_failed", message: error.localizedDescription, details: nil)) }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let status = FlutterEventChannel(name: "vpn/status", binaryMessenger: messenger)
        status.setStreamHandler(StatusStreamHandler())
    }
}

private func deviceInfo() -> [String: String] {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    var model = ""
    #if os(macOS)
    let key = "hw.model"
    #else
    let key = "hw.machine"
    #endif
    var size = 0
    if sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 {
        var buf = [CChar](repeating: 0, count: size)
        if sysctlbyname(key, &buf, &size, nil, 0) == 0 {
            model = String(cString: buf)
        }
    }
    #if os(macOS)
    let os = "macOS"
    #else
    let os = "iOS"
    #endif
    return [
        "os": os,
        "version": "\(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : ""),
        "model": model,
    ]
}

private final class StatusStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        MainActor.assumeIsolated {
            VPNManager.shared.onStatus = { status in events(status) }
            events(VPNManager.shared.currentStatus())
        }
        // On a fresh launch the system reports "disconnected" even over a live tunnel.
        Task { @MainActor in events(await VPNManager.shared.refreshStatus()) }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        MainActor.assumeIsolated { VPNManager.shared.onStatus = nil }
        return nil
    }
}
