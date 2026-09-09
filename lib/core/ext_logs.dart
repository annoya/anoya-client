import 'package:flutter/services.dart';

import 'control_transport.dart';
import 'log.dart';
import 'network_extension_core.dart';

/// Fetches the tunnel process's log files (tunnel, core) over the control
/// transport. On Apple the extension writes logs into its OWN sandbox
/// container — reading a shared App Group container from the extension is
/// TCC-gated and pops the "access data from other apps" prompt, so we pull them
/// via `sendProviderMessage` instead, and only while the tunnel is running (the
/// extension is the only process that can read them). On Windows the same
/// requests reach the service over its pipe, which answers whenever it runs.
///
/// Through the core's transport, not a MethodChannel of our own: the channel
/// exists only where a platform runner registers it, and on Windows nothing
/// does — the pipe is the channel.
ControlTransport get _control => NetworkExtensionCore.control;

/// Returns the contents of the extension log named [name] (e.g. "tunnel",
/// "mihomo"), or a human-readable placeholder if the tunnel isn't running.
Future<String> fetchExtensionLog(String name) async {
  try {
    final text = await _control.invoke<String>('fetch_log', {'name': name});
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

const _unavailable = 'Logs are available only while the tunnel is running.\n'
    '(The tunnel process keeps its logs on its own side and '
    'streams them to the app over IPC.)';

/// Names of the logs the extension keeps in its container.
const extensionLogNames = ['tunnel', 'mihomo'];

/// Wipes the extension's log files. Only possible while the tunnel is up: the
/// extension is the only process allowed into its own container, so with the
/// VPN down there is nobody to run the delete. Returns false in that case, so
/// the caller can say so instead of pretending it worked.
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

/// Tells the running extension to start/stop writing logs (its own file and the
/// engine's). Best-effort: with the tunnel down there is nobody to tell, and the
/// flag persisted in the tunnel config covers the next start.
Future<void> setExtensionLogging(bool enabled) async {
  try {
    await _control.invoke<void>('set_logging', {'enabled': enabled});
  } on PlatformException catch (e) {
    Log.e('set extension logging failed', e.message ?? e.code);
  } on MissingPluginException {
    Log.e('set extension logging failed', 'no platform side');
  }
}
