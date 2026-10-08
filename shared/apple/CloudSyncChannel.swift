import Foundation
#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

enum CloudSyncChannel {
    private static let store = NSUbiquitousKeyValueStore.default
    private static let changes = ChangeFeed()

    static func register(messenger: FlutterBinaryMessenger) {
        let methods = FlutterMethodChannel(name: "vpn/icloud", binaryMessenger: messenger)
        methods.setMethodCallHandler { call, result in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "available":
                result(FileManager.default.ubiquityIdentityToken != nil)
            case "snapshot":
                store.synchronize()
                result(store.dictionaryRepresentation.compactMapValues { $0 as? String })
            case "set":
                guard let key = args?["key"] as? String, let value = args?["value"] as? String else {
                    result(FlutterError(code: "bad_args", message: "key and value required", details: nil))
                    return
                }
                store.set(value, forKey: key)
                result(nil)
            case "remove":
                guard let key = args?["key"] as? String else {
                    result(FlutterError(code: "bad_args", message: "key required", details: nil))
                    return
                }
                store.removeObject(forKey: key)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        FlutterEventChannel(name: "vpn/icloud/changes", binaryMessenger: messenger)
            .setStreamHandler(changes)
    }

    private final class ChangeFeed: NSObject, FlutterStreamHandler {
        private var observers: [NSObjectProtocol] = []

        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            let center = NotificationCenter.default
            observers = [
                center.addObserver(
                    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: store, queue: .main
                ) { note in
                    events(note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? 0)
                },
                center.addObserver(
                    forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main
                ) { _ in
                    events(NSUbiquitousKeyValueStoreAccountChange)
                },
            ]
            store.synchronize()
            return nil
        }

        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            return nil
        }
    }
}
