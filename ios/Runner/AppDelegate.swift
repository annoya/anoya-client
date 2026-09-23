import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      VpnChannel.register(messenger: controller.binaryMessenger)
      WebAuthChannel.register(messenger: controller.binaryMessenger, anchor: window)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
