import Cocoa
import FlutterMacOS

final class MenuBarController: NSObject, NSMenuDelegate {
  private static let channelName = "vpn/tray"

  private let statusItem: NSStatusItem
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

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

  private func apply(_ args: [String: Any]) {
    statusLine = args["status"] as? String ?? ""
    detailLine = args["detail"] as? String ?? ""
    canConnect = args["can_connect"] as? Bool ?? false
    canDisconnect = args["can_disconnect"] as? Bool ?? false
    tunnelUp = args["tunnel_up"] as? Bool ?? false
    connecting = args["connecting"] as? Bool ?? false
    applyIcon()
    if let menu = statusItem.menu {
      rebuild(menu)
    }
  }

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

  func menuNeedsUpdate(_ menu: NSMenu) {
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

    menu.addItem(action("Connect", #selector(connect), enabled: canConnect))
    menu.addItem(action("Disconnect", #selector(disconnect), enabled: canDisconnect))
    menu.addItem(.separator())

    let quit = action("Quit \(appName)", #selector(quit), enabled: true)
    quit.keyEquivalent = "q"
    quit.keyEquivalentModifierMask = [.command]
    menu.addItem(quit)

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

  @objc private func toggleWindow() {
    if isAppVisible {
      // Hide the app, not the window, or it keeps key focus on an invisible window.
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
