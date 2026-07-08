import 'package:flutter/services.dart';

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
    return 'Logs are available only while the VPN is connected.\n'
        '(The tunnel extension keeps its logs in its own container and '
        'streams them to the app over IPC.)';
  }
}
