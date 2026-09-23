#include "tray_icon.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <algorithm>
#include <cstdint>

namespace {

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kIconId = 1;

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
  if (added_) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = owner_;
    nid.uID = kIconId;
    Shell_NotifyIconW(NIM_DELETE, &nid);
  }
  if (icon_) DestroyIcon(icon_);
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

void TrayIcon::AddIcon() {
  if (icon_) DestroyIcon(icon_);
  icon_ = DrawIcon(state_.tunnel_up, state_.connecting);

  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = owner_;
  nid.uID = kIconId;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  nid.uCallbackMessage = kTrayMessage;
  nid.hIcon = icon_;
  wcsncpy_s(nid.szTip, state_.status.c_str(), _TRUNCATE);
  added_ = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
  nid.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &nid);
}

void TrayIcon::UpdateIcon() {
  if (!added_) return;
  HICON fresh = DrawIcon(state_.tunnel_up, state_.connecting);
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = owner_;
  nid.uID = kIconId;
  nid.uFlags = NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  nid.hIcon = fresh;
  wcsncpy_s(nid.szTip, state_.status.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &nid);
  if (icon_) DestroyIcon(icon_);
  icon_ = fresh;
}

void TrayIcon::Apply(const flutter::EncodableMap& args) {
  if (const auto* s = GetString(args, "status")) state_.status = Widen(*s);
  if (const auto* s = GetString(args, "detail")) state_.detail = Widen(*s);
  state_.can_connect = GetBool(args, "can_connect");
  state_.can_disconnect = GetBool(args, "can_disconnect");
  state_.tunnel_up = GetBool(args, "tunnel_up");
  state_.connecting = GetBool(args, "connecting");
  UpdateIcon();
}

bool TrayIcon::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
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
  // Win32 tray quirk: the menu only closes if its owner is foreground, and the
  // trailing WM_NULL lets the next taskbar click dismiss it.
  SetForegroundWindow(owner_);
  TrackPopupMenuEx(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_RIGHTALIGN, pt.x, pt.y, owner_,
                   nullptr);
  PostMessageW(owner_, WM_NULL, 0, 0);
  DestroyMenu(menu);
}

// White with a dark outline: Windows does not recolour tray icons for a
// light or dark taskbar.
HICON TrayIcon::DrawIcon(bool filled, bool dot) const {
  const int size = GetSystemMetrics(SM_CXSMICON) > 0 ? GetSystemMetrics(SM_CXSMICON) : 16;

  BITMAPV5HEADER bi = {};
  bi.bV5Size = sizeof(bi);
  bi.bV5Width = size;
  bi.bV5Height = -size;  // top-down
  bi.bV5Planes = 1;
  bi.bV5BitCount = 32;
  bi.bV5Compression = BI_BITFIELDS;
  bi.bV5RedMask = 0x00FF0000;
  bi.bV5GreenMask = 0x0000FF00;
  bi.bV5BlueMask = 0x000000FF;
  bi.bV5AlphaMask = 0xFF000000;

  HDC screen = GetDC(nullptr);
  void* bits = nullptr;
  HBITMAP color = CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&bi), DIB_RGB_COLORS,
                                   &bits, nullptr, 0);
  HDC dc = CreateCompatibleDC(screen);
  ReleaseDC(nullptr, screen);
  if (!color || !dc || !bits) {
    if (color) DeleteObject(color);
    if (dc) DeleteDC(dc);
    return nullptr;
  }
  HGDIOBJ old_bitmap = SelectObject(dc, color);

  // Not pure black: the alpha pass below treats black as transparent.
  const COLORREF outline = RGB(40, 40, 40);
  const COLORREF fill = RGB(255, 255, 255);
  const double k = size / 16.0;
  auto px = [k](double v) { return static_cast<int>(v * k + 0.5); };

  HPEN pen = CreatePen(PS_SOLID, std::max(1, px(1.2)), outline);
  HBRUSH white = CreateSolidBrush(fill);
  // A black fill cuts a hole (see the alpha pass).
  HBRUSH hole = CreateSolidBrush(RGB(0, 0, 0));
  HGDIOBJ old_pen = SelectObject(dc, pen);
  HGDIOBJ old_brush = SelectObject(dc, white);

  POINT shield[] = {
      {px(8), px(1)},  {px(14), px(3.5)}, {px(14), px(8)},  {px(13), px(11)},
      {px(11), px(13.5)}, {px(8), px(15)},  {px(5), px(13.5)}, {px(3), px(11)},
      {px(2), px(8)},  {px(2), px(3.5)},
  };
  Polygon(dc, shield, static_cast<int>(sizeof(shield) / sizeof(shield[0])));
  if (!filled) {
    SelectObject(dc, hole);
    POINT inner[] = {
        {px(8), px(3.6)},  {px(12), px(5.2)}, {px(12), px(8)}, {px(11.2), px(10.2)},
        {px(9.8), px(11.9)}, {px(8), px(12.8)}, {px(6.2), px(11.9)}, {px(4.8), px(10.2)},
        {px(4), px(8)}, {px(4), px(5.2)},
    };
    Polygon(dc, inner, static_cast<int>(sizeof(inner) / sizeof(inner[0])));
    if (dot) {
      SelectObject(dc, white);
      Ellipse(dc, px(6), px(6), px(10.5), px(10.5));
    }
  }
  SelectObject(dc, old_brush);
  SelectObject(dc, old_pen);
  DeleteObject(pen);
  DeleteObject(white);
  DeleteObject(hole);
  GdiFlush();

  // GDI leaves alpha at zero; make every non-black pixel opaque.
  auto* pixels = static_cast<uint32_t*>(bits);
  for (int i = 0; i < size * size; i++) {
    if (pixels[i] & 0x00FFFFFF) pixels[i] |= 0xFF000000;
  }

  SelectObject(dc, old_bitmap);
  DeleteDC(dc);

  HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
  ICONINFO ii = {};
  ii.fIcon = TRUE;
  ii.hbmColor = color;
  ii.hbmMask = mask;
  HICON icon = CreateIconIndirect(&ii);
  DeleteObject(mask);
  DeleteObject(color);
  return icon;
}
