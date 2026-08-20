import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Closing the window leaves the app running in the menu bar.
  ///
  /// It used to quit, which cannot coexist with a menu bar item: the item would
  /// vanish with the window, and "Show" would have nothing left to show. The
  /// app stays in the Dock as well — hiding it from there is a different
  /// product (an accessory app you launch differently), not a menu.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
