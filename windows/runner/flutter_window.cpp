#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  tray_ = std::make_unique<TrayIcon>(GetHandle(), flutter_controller_->engine()->messenger(),
                                     L"AnnoyaTest");
  tray_->on_toggle_window = [this]() { ToggleWindow(); };
  tray_->on_quit = [this]() {
    quitting_ = true;
    Destroy();
  };

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Before the engine: the icon's channel handler holds a messenger the
  // engine owns.
  tray_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::ToggleWindow() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (IsWindowVisible(hwnd) && !IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_HIDE);
  } else {
    ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(hwnd);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The tray's callback and its menu commands are ours before they are
  // anybody's: a plugin's window-proc hook must not swallow a WM_COMMAND
  // meant for the menu.
  if (tray_ && tray_->HandleMessage(message, wparam, lparam)) {
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // The close button hides the window into the tray; the app keeps running
    // with the icon as its only surface. Quit from the menu sets quitting_
    // and the default close (DestroyWindow) proceeds.
    case WM_CLOSE:
      if (!quitting_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
