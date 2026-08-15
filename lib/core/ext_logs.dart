import 'package:flutter/services.dart';

import 'log.dart';

/// Fetches the Network Extension's log files (tunnel, core) over the provider
/// IPC channel. The extension writes logs into its OWN sandbox container —
/// reading a shared App Group container from the extension is TCC-gated and
/// pops the "access data from other apps" prompt, so we pull them via
/// `sendProviderMessage` instead. Logs are only available while the tunnel is
/// running (the extension is the only process that can read them).
const _control = MethodChannel('vpn/control');

/// Returns the contents of the extension log named [name] (e.g. "tunnel",
/// "mihomo"), or a human-readable placeholder if the tunnel isn't running.
Future<String> fetchExtensionLog(String name) async {
  try {
    final text = await _control.invokeMethod<String>('fetch_log', {'name': name});
    final t = text ?? '';
    return t.trim().isEmpty ? 'No log yet.' : t;
  } on PlatformException {
    return _unavailable;
  } on MissingPluginException {
    // Thrown instead of PlatformException when no handler is registered — the
    // same "nothing is running" situation, and not a PlatformException subtype.
    return _unavailable;
  }
}

const _unavailable = 'Logs are available only while the VPN is connected.\n'
    '(The tunnel extension keeps its logs in its own container and '
    'streams them to the app over IPC.)';

/// Names of the logs the extension keeps in its container.
const extensionLogNames = ['tunnel', 'mihomo'];

/// Wipes the extension's log files. Only possible while the tunnel is up: the
/// extension is the only process allowed into its own container, so with the
/// VPN down there is nobody to run the delete. Returns false in that case, so
/// the caller can say so instead of pretending it worked.
Future<bool> clearExtensionLogs() async {
  try {
    await _control.invokeMethod<void>('clear_logs');
    return true;
  } on PlatformException catch (e) {
    Log.e('clear extension logs failed', e.message ?? e.code);
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// Tells the running extension to start/stop writing logs (its own file and the
/// engine's). Best-effort: with the tunnel down there is nobody to tell, and the
/// flag persisted in the tunnel config covers the next start.
Future<void> setExtensionLogging(bool enabled) async {
  try {
    await _control.invokeMethod<void>('set_logging', {'enabled': enabled});
  } on PlatformException catch (e) {
    Log.e('set extension logging failed', e.message ?? e.code);
  } on MissingPluginException {
    Log.e('set extension logging failed', 'no platform side');
  }
}
