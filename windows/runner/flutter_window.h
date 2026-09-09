#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "tray_icon.h"
#include "win32_window.h"

// A window that hosts the Flutter view and owns the tray icon. Closing the
// window hides it into the tray rather than quitting — the tunnel lives in a
// service and the icon is the only way to reach it once the window is gone;
// quitting is the tray menu's Quit.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The notification-area icon; created once the engine has a messenger.
  std::unique_ptr<TrayIcon> tray_;

  // Set by Quit, so the close that follows is allowed to destroy the window.
  bool quitting_ = false;

  void ToggleWindow();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
