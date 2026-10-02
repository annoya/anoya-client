#ifndef RUNNER_CLIPBOARD_HISTORY_PASTE_H_
#define RUNNER_CLIPBOARD_HISTORY_PASTE_H_

#include <windows.h>

class ClipboardHistoryPaste {
 public:
  bool Intercept(const MSG& msg);

 private:
  void SendPaste();

  bool ctrl_held_ = false;
};

#endif  // RUNNER_CLIPBOARD_HISTORY_PASTE_H_
