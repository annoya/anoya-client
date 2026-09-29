import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'control_transport.dart';
import 'log.dart';
import 'network_extension_core.dart';

// Reading the App Group container from the extension pops a TCC prompt.
ControlTransport get _control => NetworkExtensionCore.control;

Future<String> fetchExtensionLog(String name) async {
  try {
    final text = await _control.invoke<String>('fetch_log', {'name': name});
    final t = text ?? '';
    return t.trim().isEmpty ? L10n.current.logsNoLogYet : t;
  } on PlatformException {
    return _unavailable;
  } on MissingPluginException {
    return _unavailable;
  }
}

String get _unavailable => L10n.current.logsUnavailable;

const extensionLogNames = ['tunnel', 'mihomo'];

Future<bool> clearExtensionLogs() async {
  try {
    await _control.invoke<void>('clear_logs');
    return true;
  } on PlatformException catch (e) {
    Log.e('clear extension logs failed', e.message ?? e.code);
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<void> setExtensionLogging(bool enabled) async {
  try {
    await _control.invoke<void>('set_logging', {'enabled': enabled});
  } on PlatformException catch (e) {
    Log.e('set extension logging failed', e.message ?? e.code);
  } on MissingPluginException {
    Log.e('set extension logging failed', 'no platform side');
  }
}
