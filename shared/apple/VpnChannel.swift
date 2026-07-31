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
                Task {
                    do { try await VPNManager.shared.prepare(); result(nil) }
                    catch { result(FlutterError(code: "prepare_failed", message: error.localizedDescription, details: nil)) }
                }
            case "start":
                let args = call.arguments as? [String: Any]
                guard let config = args?["config"] as? String else {
                    result(FlutterError(code: "bad_args", message: "config required", details: nil))
                    return
                }
                let serverIp = args?["server_ip"] as? String
                Task {
                    do { try await VPNManager.shared.start(config: config, serverIp: serverIp); result(nil) }
                    catch { result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil)) }
                }
            case "stop":
                VPNManager.shared.stop()
                result(nil)
            case "status":
                result(VPNManager.shared.currentStatus())
            case "shared_dir":
                // App Group container shared with the tunnel extension — the
                // engine's home dir, where GeoIP/GeoSite databases live. Dart
                // writes there with dart:io (POSIX), which avoids the macOS
                // "access data from other apps" TCC probe.
                let url = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.nt.vpnClient")
                result(url?.path)
            case "fetch_log":
                // Pull a log file from the running extension over provider IPC
                // (the extension logs into its own container, not a shared one).
                let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
                Task {
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

private final class StatusStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        VPNManager.shared.onStatus = { status in events(status) }
        events(VPNManager.shared.currentStatus()) // emit initial state
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        VPNManager.shared.onStatus = nil
        return nil
    }
}
