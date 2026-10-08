#include "tray_icon.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include "resource.h"

namespace {

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kIconId = 1;
constexpr UINT_PTR kWinkTimerId = 1;
constexpr UINT kWinkIntervalMs = 1000;

constexpr UINT kCmdToggleWindow = 1001;
constexpr UINT kCmdConnect = 1002;
constexpr UINT kCmdDisconnect = 1003;
constexpr UINT kCmdQuit = 1004;
constexpr UINT kCmdLabel = 1100;

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return L"";
  int n = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), out.data(), n);
  return out;
}

const std::string* GetString(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : std::get_if<std::string>(&it->second);
}

HICON LoadTrayIcon(int id) {
  const int size = GetSystemMetrics(SM_CXSMICON) > 0 ? GetSystemMetrics(SM_CXSMICON) : 16;
  return static_cast<HICON>(LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(id), IMAGE_ICON,
                                       size, size, LR_DEFAULTCOLOR));
}

bool AnimationsEnabled() {
  BOOL enabled = TRUE;
  SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &enabled, 0);
  return enabled != FALSE;
}

bool GetBool(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return false;
  const bool* b = std::get_if<bool>(&it->second);
  return b && *b;
}

}  // namespace

TrayIcon::TrayIcon(HWND owner, flutter::BinaryMessenger* messenger, std::wstring app_name)
    : owner_(owner), app_name_(std::move(app_name)) {
  taskbar_created_ = RegisterWindowMessageW(L"TaskbarCreated");
  closed_icon_ = LoadTrayIcon(IDI_TRAY_CLOSED);
  open_icon_ = LoadTrayIcon(IDI_TRAY_OPEN);
  wink_left_icon_ = LoadTrayIcon(IDI_TRAY_WINK_L);
  wink_right_icon_ = LoadTrayIcon(IDI_TRAY_WINK_R);

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "vpn/tray", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "update") {
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            Apply(*map);
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  state_.status = L"Not connected";
  AddIcon();
}

TrayIcon::~TrayIcon() {
  KillTimer(owner_, kWinkTimerId);
  if (added_) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = owner_;
    nid.uID = kIconId;
    Shell_NotifyIconW(NIM_DELETE, &nid);
  }
  for (HICON icon : {closed_icon_, open_icon_, wink_left_icon_, wink_right_icon_}) {
    if (icon) DestroyIcon(icon);
  }
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

void TrayIcon::AddIcon() {
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = owner_;
  nid.uID = kIconId;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  nid.uCallbackMessage = kTrayMessage;
  nid.hIcon = CurrentIcon();
  wcsncpy_s(nid.szTip, state_.status.c_str(), _TRUNCATE);
  added_ = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
  nid.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &nid);
}

void TrayIcon::UpdateIcon() {
  if (!added_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = owner_;
  nid.uID = kIconId;
  nid.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  nid.hIcon = CurrentIcon();
  wcsncpy_s(nid.szTip, state_.status.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &nid);
}

HICON TrayIcon::CurrentIcon() const {
  if (state_.connecting) return wink_right_ ? wink_right_icon_ : wink_left_icon_;
  return state_.tunnel_up ? open_icon_ : closed_icon_;
}

void TrayIcon::StartWink() {
  winking_ = true;
  wink_right_ = false;
  if (AnimationsEnabled()) SetTimer(owner_, kWinkTimerId, kWinkIntervalMs, nullptr);
}

void TrayIcon::StopWink() {
  KillTimer(owner_, kWinkTimerId);
  winking_ = false;
  wink_right_ = false;
}

void TrayIcon::Wink() {
  wink_right_ = !wink_right_;
  UpdateIcon();
}

void TrayIcon::Apply(const flutter::EncodableMap& args) {
  if (const auto* s = GetString(args, "status")) state_.status = Widen(*s);
  if (const auto* s = GetString(args, "detail")) state_.detail = Widen(*s);
  state_.can_connect = GetBool(args, "can_connect");
  state_.can_disconnect = GetBool(args, "can_disconnect");
  state_.tunnel_up = GetBool(args, "tunnel_up");
  state_.connecting = GetBool(args, "connecting");
  if (state_.connecting && !winking_) StartWink();
  if (!state_.connecting && winking_) StopWink();
  UpdateIcon();
}

bool TrayIcon::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_TIMER && wparam == kWinkTimerId) {
    Wink();
    return true;
  }
  if (message == kTrayMessage) {
    switch (LOWORD(lparam)) {
      case WM_CONTEXTMENU:
        ShowMenu();
        return true;
      case NIN_SELECT:
      case NIN_KEYSELECT:
        if (on_toggle_window) on_toggle_window();
        return true;
    }
    return true;
  }
  if (taskbar_created_ && message == taskbar_created_) {
    added_ = false;
    AddIcon();
    return true;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == 0) {
    switch (LOWORD(wparam)) {
      case kCmdToggleWindow:
        if (on_toggle_window) on_toggle_window();
        return true;
      case kCmdConnect:
        channel_->InvokeMethod("connect", nullptr);
        return true;
      case kCmdDisconnect:
        channel_->InvokeMethod("disconnect", nullptr);
        return true;
      case kCmdQuit:
        if (on_quit) on_quit();
        return true;
    }
  }
  return false;
}

void TrayIcon::ShowMenu() {
  channel_->InvokeMethod("sync", nullptr);

  HMENU menu = CreatePopupMenu();
  if (!menu) return;
  UINT label_id = kCmdLabel;
  if (!state_.status.empty()) {
    AppendMenuW(menu, MF_STRING | MF_GRAYED, label_id++, state_.status.c_str());
  }
  if (!state_.detail.empty()) {
    AppendMenuW(menu, MF_STRING | MF_GRAYED, label_id++, state_.detail.c_str());
  }
  if (label_id != kCmdLabel) AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);

  const bool visible = IsWindowVisible(owner_) && !IsIconic(owner_);
  std::wstring window_item = (visible ? L"Hide " : L"Show ") + app_name_;
  AppendMenuW(menu, MF_STRING, kCmdToggleWindow, window_item.c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING | (state_.can_connect ? 0 : MF_GRAYED), kCmdConnect, L"Connect");
  AppendMenuW(menu, MF_STRING | (state_.can_disconnect ? 0 : MF_GRAYED), kCmdDisconnect,
              L"Disconnect");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  std::wstring quit_item = L"Quit " + app_name_;
  AppendMenuW(menu, MF_STRING, kCmdQuit, quit_item.c_str());
  if (state_.tunnel_up) {
    AppendMenuW(menu, MF_STRING | MF_GRAYED, label_id++, L"Quitting leaves the tunnel connected");
  }

  POINT pt;
  GetCursorPos(&pt);
  // Win32 tray quirk: the menu only dismisses if its owner is foreground plus a trailing WM_NULL.
  SetForegroundWindow(owner_);
  TrackPopupMenuEx(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_RIGHTALIGN, pt.x, pt.y, owner_,
                   nullptr);
  PostMessageW(owner_, WM_NULL, 0, 0);
  DestroyMenu(menu);
}
