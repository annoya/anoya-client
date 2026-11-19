#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "tray_icon.h"
#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);

  // Started at sign-in: the window stays in the tray until it is asked for.
  void SetStartHidden(bool hidden) { start_hidden_ = hidden; }
  virtual ~FlutterWindow();

  static UINT ShowWindowMessage();

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

  std::unique_ptr<TrayIcon> tray_;

  bool quitting_ = false;
  bool start_hidden_ = false;

  void ToggleWindow();
  void BringToFront();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
