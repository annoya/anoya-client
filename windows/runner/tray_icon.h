#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <string>

class TrayIcon {
 public:
  TrayIcon(HWND owner, flutter::BinaryMessenger* messenger,
           std::wstring app_name);
  ~TrayIcon();

  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

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
  void StartWink();
  void StopWink();
  void Wink();
  HICON CurrentIcon() const;

  HWND owner_;
  std::wstring app_name_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  State state_;
  HICON closed_icon_ = nullptr;
  HICON open_icon_ = nullptr;
  HICON wink_left_icon_ = nullptr;
  HICON wink_right_icon_ = nullptr;
  bool winking_ = false;
  bool wink_right_ = false;
  bool added_ = false;
  UINT taskbar_created_ = 0;
};

#endif  // RUNNER_TRAY_ICON_H_
