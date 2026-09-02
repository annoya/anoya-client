import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var menuBar: MenuBarController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Phone-shaped by default (close to the 393×852 the screens are designed
    // for), but the user resizes it freely — a locked window on a desktop is a
    // nuisance, and the layouts already stretch.
    self.setContentSize(NSSize(width: 400, height: 700))
    self.contentMinSize = NSSize(width: 360, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // VPN control/status bridge to the packet-tunnel extension.
    VpnChannel.register(messenger: flutterViewController.engine.binaryMessenger)

    // SSO: system auth browser (ASWebAuthenticationSession) for the OIDC flow.
    WebAuthChannel.register(messenger: flutterViewController.engine.binaryMessenger, anchor: self)

    // Menu bar item. Held by the window because it must outlive every menu it
    // shows: an NSStatusItem released early takes its slot out of the menu bar.
    menuBar = MenuBarController(
      messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}
