import 'package:flutter/services.dart';

abstract class ControlTransport {
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]);

  Stream<String?> get statusEvents;
}

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
