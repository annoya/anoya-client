#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// The notification-area icon and its menu: the Windows counterpart of the
// macOS menu bar item (MenuBarController.swift), speaking the same "vpn/tray"
// channel. Dart composes every word the menu shows (menu_bar_controller.dart);
// this class owns only the surface — the icon, the popup menu, the window's
// show/hide — and asks Dart to connect or disconnect.
//
// Bare Win32: Shell_NotifyIcon for the icon, TrackPopupMenu for the menu,
// GDI for the icon itself, which is drawn at runtime so the shape can follow
// the tunnel's state the way the macOS symbol does.
class TrayIcon {
 public:
  // |owner| receives the tray callback and the menu commands through
  // HandleMessage; |app_name| is what "Show …" and "Quit …" say.
  TrayIcon(HWND owner, flutter::BinaryMessenger* messenger,
           std::wstring app_name);
  ~TrayIcon();

  // Routes one window message. Returns true when it was the tray's.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

  // What the menu's window item and Quit do; the window owns both decisions.
  std::function<void()> on_toggle_window;
  std::function<void()> on_quit;

 private:
  struct State {
    std::wstring status;
    std::wstring detail;
    bool can_connect = false;
    bool can_disconnect = false;
    bool tunnel_up = false;
    bool connecting = false;
  };

  void Apply(const flutter::EncodableMap& args);
  void AddIcon();
  void UpdateIcon();
  void ShowMenu();
  HICON DrawIcon(bool filled, bool dot) const;

  HWND owner_;
  std::wstring app_name_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  State state_;
  HICON icon_ = nullptr;
  bool added_ = false;
  // Explorer announces its restart with this; the icon has to be added again.
  UINT taskbar_created_ = 0;
};

#endif  // RUNNER_TRAY_ICON_H_
