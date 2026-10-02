#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "clipboard_history_paste.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

void ActivateRunningInstance() {
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Anoya");
  if (!existing) {
    return;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(existing, &pid);
  ::AllowSetForegroundWindow(pid);
  ::PostMessageW(existing, FlutterWindow::ShowWindowMessage(), 0, 0);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\Anoya.SingleInstance");
  if (instance_mutex && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateRunningInstance();
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(420, 760);
  if (!window.Create(L"Anoya", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ClipboardHistoryPaste clipboard_history_paste;
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    if (clipboard_history_paste.Intercept(msg)) {
      continue;
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex) {
    ::CloseHandle(instance_mutex);
  }
  return EXIT_SUCCESS;
}
