import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var menuBar: MenuBarController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.setContentSize(NSSize(width: 400, height: 700))
    self.contentMinSize = NSSize(width: 360, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    VpnChannel.register(messenger: flutterViewController.engine.binaryMessenger)
    WebAuthChannel.register(messenger: flutterViewController.engine.binaryMessenger, anchor: self)

    // Held by the window: an NSStatusItem released early disappears from the menu bar.
    menuBar = MenuBarController(
      messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}
