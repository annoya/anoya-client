import Cocoa
import FlutterMacOS

/// The menu bar item and its menu — AppKit's own `NSStatusItem` + `NSMenu`,
/// not a drawn imitation. The system owns the surface: appearance, metrics,
/// highlight, keyboard handling and the ⌘Q equivalent all come from it.
///
/// The split of responsibility is deliberate. Showing, hiding and quitting are
/// window-server business and are done here, without a round trip to Dart —
/// they must work even if the Flutter isolate is busy. Connecting and
/// disconnecting are not: the app refreshes managed profiles before a connect,
/// applies routing policy and reports errors, so those are forwarded to Dart
/// and nothing about the tunnel is decided in this file.
///
/// Menu text comes from Dart for the same reason: the status line is the same
/// sentence the home screen shows, and formatting it twice is how the two start
/// disagreeing.
final class MenuBarController: NSObject, NSMenuDelegate {
  private static let channelName = "vpn/tray"

  private let statusItem: NSStatusItem
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

  /// Everything the menu shows, as last pushed from Dart. Defaults describe an
  /// app that has not reported yet: no promises about the tunnel, and the only
  /// actions offered are the ones this file can honour on its own.
  private var statusLine = ""
  private var detailLine = ""
  private var canConnect = false
  private var canDisconnect = false
  private var tunnelUp = false
  private var connecting = false

  private var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "VPN"
  }

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    channel = FlutterMethodChannel(name: MenuBarController.channelName,
                                   binaryMessenger: messenger)
    self.window = window
    super.init()

    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
    statusItem.button?.toolTip = appName
    applyIcon()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "update":
        self.apply(call.arguments as? [String: Any] ?? [:])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func register(messenger: FlutterBinaryMessenger, window: NSWindow) -> MenuBarController {
    MenuBarController(messenger: messenger, window: window)
  }

  // MARK: - State from Dart

  private func apply(_ args: [String: Any]) {
    statusLine = args["status"] as? String ?? ""
    detailLine = args["detail"] as? String ?? ""
    canConnect = args["can_connect"] as? Bool ?? false
    canDisconnect = args["can_disconnect"] as? Bool ?? false
    tunnelUp = args["tunnel_up"] as? Bool ?? false
    connecting = args["connecting"] as? Bool ?? false
    applyIcon()
    // The menu is rebuilt when it opens; if it is already open, the user is
    // looking at it right now and the new state has to land immediately.
    if let menu = statusItem.menu, menu.highlightedItem != nil || menu.numberOfItems > 0 {
      rebuild(menu)
    }
  }

  /// State is carried by shape, because colour is not available here: a status
  /// item's image is a template, which the system tints (black on a light menu
  /// bar, white on a dark one) with no say from us.
  private func applyIcon() {
    guard let button = statusItem.button else { return }
    let name: String
    let fallbackFilled: Bool
    if connecting {
      name = "arrow.triangle.2.circlepath"
      fallbackFilled = false
    } else if tunnelUp {
      name = "lock.shield.fill"
      fallbackFilled = true
    } else {
      name = "lock.shield"
      fallbackFilled = false
    }
    if #available(macOS 11.0, *) {
      let image = NSImage(systemSymbolName: name, accessibilityDescription: statusLine)
      image?.isTemplate = true
      button.image = image
      if button.image != nil { return }
    }
    // macOS 10.15 has no SF Symbols. The silhouette differs from the symbols
    // above, but the distinction the menu bar has to carry — filled means the
    // tunnel is up — survives.
    button.image = MenuBarController.drawnShield(filled: fallbackFilled)
  }

  private static func drawnShield(filled: Bool) -> NSImage {
    let size = NSSize(width: 16, height: 16)
    let image = NSImage(size: size)
    image.lockFocus()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 8, y: 15))
    path.line(to: NSPoint(x: 14, y: 12))
    path.line(to: NSPoint(x: 14, y: 7))
    path.curve(to: NSPoint(x: 8, y: 1),
               controlPoint1: NSPoint(x: 14, y: 4),
               controlPoint2: NSPoint(x: 11, y: 2))
    path.curve(to: NSPoint(x: 2, y: 7),
               controlPoint1: NSPoint(x: 5, y: 2),
               controlPoint2: NSPoint(x: 2, y: 4))
    path.line(to: NSPoint(x: 2, y: 12))
    path.close()
    NSColor.black.set()
    if filled {
      path.fill()
    } else {
      path.lineWidth = 1.5
      path.stroke()
    }
    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  // MARK: - Menu

  func menuNeedsUpdate(_ menu: NSMenu) {
    // Ask Dart for a fresh snapshot on every open: the session timer runs
    // there, and a menu that opens showing the duration from the last status
    // change would be quietly stale.
    channel.invokeMethod("sync", arguments: nil)
    rebuild(menu)
  }

  private func rebuild(_ menu: NSMenu) {
    menu.removeAllItems()

    if !statusLine.isEmpty { menu.addItem(label(statusLine)) }
    if !detailLine.isEmpty { menu.addItem(label(detailLine)) }
    if menu.numberOfItems > 0 { menu.addItem(.separator()) }

    let visible = isAppVisible
    menu.addItem(action(visible ? "Hide \(appName)" : "Show \(appName)",
                        #selector(toggleWindow),
                        enabled: true))
    menu.addItem(.separator())

    // Both are always present, and the inapplicable one is disabled rather
    // than removed: items that come and go move everything below them, and the
    // click that was aimed at Quit lands on something else.
    menu.addItem(action("Connect", #selector(connect), enabled: canConnect))
    menu.addItem(action("Disconnect", #selector(disconnect), enabled: canDisconnect))
    menu.addItem(.separator())

    let quit = action("Quit \(appName)", #selector(quit), enabled: true)
    quit.keyEquivalent = "q"
    quit.keyEquivalentModifierMask = [.command]
    menu.addItem(quit)

    // The tunnel lives in a system extension, so quitting does not take it
    // down (and with on-demand armed the system brings it back). Leaving a VPN
    // up with no window and no word about it would be a surprise; the line is
    // only true while it is up, so it only appears then.
    if tunnelUp { menu.addItem(label("Quitting leaves the tunnel connected")) }
  }

  private func label(_ title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  private func action(_ title: String, _ selector: Selector, enabled: Bool) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: enabled ? selector : nil, keyEquivalent: "")
    item.target = self
    item.isEnabled = enabled
    return item
  }

  private var isAppVisible: Bool {
    guard let window else { return false }
    return window.isVisible && !NSApp.isHidden
  }

  // MARK: - Actions

  @objc private func toggleWindow() {
    if isAppVisible {
      // The app, not just the window: "Hide <App>" is a system-wide verb, and
      // hiding only the window would leave a menu bar app that still holds the
      // keyboard focus of a window nobody can see.
      NSApp.hide(nil)
    } else {
      NSApp.unhide(nil)
      window?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  @objc private func connect() { channel.invokeMethod("connect", arguments: nil) }

  @objc private func disconnect() { channel.invokeMethod("disconnect", arguments: nil) }

  @objc private func quit() { NSApp.terminate(nil) }
}
