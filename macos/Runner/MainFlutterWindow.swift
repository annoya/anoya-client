import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Default phone-ish window size; resizable, with a sane minimum.
    self.setContentSize(NSSize(width: 400, height: 600))
    self.minSize = NSSize(width: 360, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // VPN control/status bridge to the packet-tunnel extension.
    VpnChannel.register(messenger: flutterViewController.engine.binaryMessenger)

    // SSO: system auth browser (ASWebAuthenticationSession) for the OIDC flow.
    WebAuthChannel.register(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}
