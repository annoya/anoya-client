import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static let showWindowNotification = Notification.Name(
    (Bundle.main.bundleIdentifier ?? "Runner") + ".showWindow")

  override init() {
    super.init()
    if let running = AppDelegate.otherInstance() {
      DistributedNotificationCenter.default().postNotificationName(
        AppDelegate.showWindowNotification, object: nil, userInfo: nil,
        deliverImmediately: true)
      running.activate(options: [])
      exit(0)
    }
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    DistributedNotificationCenter.default().addObserver(
      forName: AppDelegate.showWindowNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.showMainWindow()
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { showMainWindow() }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func showMainWindow() {
    NSApp.unhide(nil)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private static func otherInstance() -> NSRunningApplication? {
    guard let id = Bundle.main.bundleIdentifier else { return nil }
    let me = ProcessInfo.processInfo.processIdentifier
    return NSRunningApplication.runningApplications(withBundleIdentifier: id)
      .first { $0.processIdentifier != me && !$0.isTerminated }
  }
}
