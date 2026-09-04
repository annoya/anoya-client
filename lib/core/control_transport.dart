import 'package:flutter/services.dart';

/// How the app reaches the process that runs the tunnel.
///
/// On Apple and Android that process is behind a MethodChannel and an
/// EventChannel the platform runner registers; on Windows it is a service on
/// the far end of a named pipe. The vocabulary is the same — method names,
/// argument maps, status strings — so [NetworkExtensionCore] speaks it once and
/// the transport is the only thing that differs.
abstract class ControlTransport {
  /// One request, one answer. A refusal arrives as a [PlatformException]
  /// carrying the platform's message; a transport with no platform side at
  /// all throws [MissingPluginException], which callers treat as "unavailable"
  /// rather than as an error.
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]);

  /// The tunnel's status as the platform reports it: `connected`,
  /// `connecting`, `disconnected`, `error`. The current value is delivered
  /// first, then every change.
  Stream<String?> get statusEvents;
}

/// The platform channels the Apple and Android runners register.
class ChannelTransport implements ControlTransport {
  static const _control = MethodChannel('vpn/control');
  static const _status = EventChannel('vpn/status');

  @override
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) =>
      _control.invokeMethod<T>(method, args);

  @override
  Stream<String?> get statusEvents =>
      _status.receiveBroadcastStream().map((e) => e as String?);
}
