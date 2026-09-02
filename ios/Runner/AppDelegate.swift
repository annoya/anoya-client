import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // VPN control/status bridge to the packet-tunnel extension.
    if let controller = window?.rootViewController as? FlutterViewController {
      VpnChannel.register(messenger: controller.binaryMessenger)
      // SSO: system auth browser (ASWebAuthenticationSession) for the OIDC flow.
      WebAuthChannel.register(messenger: controller.binaryMessenger, anchor: window)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
