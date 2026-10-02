#include "clipboard_history_paste.h"

namespace {

UINT ScanCode(LPARAM lparam) {
  return static_cast<UINT>((lparam >> 16) & 0xFF);
}

INPUT Key(WORD vk, bool up) {
  INPUT input = {};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = vk;
  input.ki.wScan = static_cast<WORD>(MapVirtualKeyW(vk, MAPVK_VK_TO_VSC));
  input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
  return input;
}

}  // namespace

bool ClipboardHistoryPaste::Intercept(const MSG& msg) {
  if (msg.message != WM_KEYDOWN && msg.message != WM_KEYUP) return false;
  if (ScanCode(msg.lParam) != 0) return false;
  const bool down = msg.message == WM_KEYDOWN;
  switch (msg.wParam) {
    case VK_CONTROL:
    case VK_LCONTROL:
      if (down) {
        ctrl_held_ = true;
        return true;
      }
      if (!ctrl_held_) return false;
      ctrl_held_ = false;
      return true;
    case 'V':
      if (!ctrl_held_) return false;
      if (down) SendPaste();
      return true;
  }
  return false;
}

void ClipboardHistoryPaste::SendPaste() {
  INPUT inputs[] = {
      Key(VK_LCONTROL, false),
      Key('V', false),
      Key('V', true),
      Key(VK_LCONTROL, true),
  };
  SendInput(static_cast<UINT>(ARRAYSIZE(inputs)), inputs, sizeof(INPUT));
}
