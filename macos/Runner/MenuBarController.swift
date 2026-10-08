import Cocoa
import FlutterMacOS

final class MenuBarController: NSObject, NSMenuDelegate {
  private static let channelName = "vpn/tray"
  private static let winkInterval: TimeInterval = 1

  private let closedIcon = NSImage(named: "TrayClosed")
  private let openIcon = NSImage(named: "TrayOpen")
  private let winkLeftIcon = NSImage(named: "TrayWinkL")
  private let winkRightIcon = NSImage(named: "TrayWinkR")

  private let statusItem: NSStatusItem
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

  private var statusLine = ""
  private var detailLine = ""
  private var canConnect = false
  private var canDisconnect = false
  private var tunnelUp = false
  private var connecting = false
  private var winkTimer: Timer?
  private var winking = false
  private var winkRight = false

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
    if connecting && !winking { startWink() }
    if !connecting && winking { stopWink() }
    guard let button = statusItem.button else { return }
    if connecting {
      button.image = winkRight ? winkRightIcon : winkLeftIcon
    } else {
      button.image = tunnelUp ? openIcon : closedIcon
    }
    button.setAccessibilityLabel(statusLine)
  }

  private func startWink() {
    winking = true
    winkRight = false
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
    let timer = Timer(timeInterval: MenuBarController.winkInterval, repeats: true) { [weak self] _ in
      self?.wink()
    }
    RunLoop.main.add(timer, forMode: .common)
    winkTimer = timer
  }

  private func stopWink() {
    winkTimer?.invalidate()
    winkTimer = nil
    winking = false
    winkRight = false
  }

  private func wink() {
    winkRight.toggle()
    applyIcon()
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
