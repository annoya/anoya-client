#if canImport(FlutterMacOS)
import FlutterMacOS
#else
import Flutter
#endif
import Foundation

/// VpnChannel bridges Flutter <-> VPNManager.
///   MethodChannel "vpn/control":  start(config) / stop / status / prepare
///   EventChannel  "vpn/status":   stream of "connected|connecting|disconnected"
enum VpnChannel {
    static func register(messenger: FlutterBinaryMessenger) {
        let control = FlutterMethodChannel(name: "vpn/control", binaryMessenger: messenger)
        control.setMethodCallHandler { call, result in
            switch call.method {
            case "prepare":
                Task { @MainActor in
                    do { try await VPNManager.shared.prepare(); result(nil) }
                    catch { result(FlutterError(code: "prepare_failed", message: error.localizedDescription, details: nil)) }
                }
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
                        // Returns whether the system actually armed — it refuses
                        // when there is no tunnel config to start from.
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
                // Hot-swap the running tunnel onto a new config (location or
                // profile switch) without dropping the NE session.
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
                // Mirror the current selection into the saved profile without
                // starting anything (and without creating the profile).
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
            case "status":
                Task { @MainActor in result(await VPNManager.shared.refreshStatus()) }
            case "group_member":
                let name = (call.arguments as? [String: Any])?["group"] as? String ?? ""
                Task { @MainActor in result(await VPNManager.shared.groupMember(name)) }
            case "device_info":
                result(deviceInfo())
            case "shared_dir":
                // App Group container shared with the tunnel extension — the
                // engine's home dir, where GeoIP/GeoSite databases live. Dart
                // writes there with dart:io (POSIX), which avoids the macOS
                // "access data from other apps" TCC probe.
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
                // Only the extension may delete files in its own container, so
                // this needs a running tunnel — the app side says so when it
                // fails rather than pretending the logs are gone.
                Task { @MainActor in
                    do { try await VPNManager.shared.clearLogs(); result(nil) }
                    catch { result(FlutterError(code: "clear_logs_failed",
                                                message: error.localizedDescription, details: nil)) }
                }
            case "fetch_log":
                // Pull a log file from the running extension over provider IPC
                // (the extension logs into its own container, not a shared one).
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

/// What this device is, for the subscription panels that count devices.
///
/// The model comes from sysctl rather than the host name: `hw.model` is
/// "MacBookPro18,3", while the host name is routinely "Ivan's MacBook Pro" —
/// which would hand a third-party panel the user's name for nothing.
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
        VPNManager.shared.onStatus = { status in events(status) }
        events(VPNManager.shared.currentStatus()) // what we know right now
        // …and what is actually true: on a fresh launch the app has not touched
        // the system profile yet, so the line above says "disconnected" even
        // over a live tunnel. Adopting the existing profile publishes the real
        // status (and starts the status observer) as soon as it loads.
        Task { @MainActor in events(await VPNManager.shared.refreshStatus()) }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        VPNManager.shared.onStatus = nil
        return nil
    }
}
