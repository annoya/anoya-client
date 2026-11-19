import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const kStartHiddenArgument = '--hidden';

const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _valueName = 'Anoya';

String loginCommand(String executable) => '"$executable" $kStartHiddenArgument';

// The service brings the tunnel up at boot with no window; this puts the tray icon next to it.
void setStartsAtLogin(bool enabled) {
  if (!Platform.isWindows) return;
  final key = _runKey.toNativeUtf16(allocator: calloc);
  final name = _valueName.toNativeUtf16(allocator: calloc);
  try {
    if (!enabled) {
      RegDeleteKeyValue(HKEY_CURRENT_USER, PCWSTR(key), PCWSTR(name));
      return;
    }
    final command = loginCommand(Platform.resolvedExecutable);
    final data = command.toNativeUtf16(allocator: calloc);
    try {
      RegSetKeyValue(
        HKEY_CURRENT_USER,
        PCWSTR(key),
        PCWSTR(name),
        REG_SZ,
        data,
        (command.length + 1) * sizeOf<Uint16>(),
      );
    } finally {
      calloc.free(data);
    }
  } finally {
    calloc.free(key);
    calloc.free(name);
  }
}
