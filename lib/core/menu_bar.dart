import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'log.dart';

class MenuBarState {
  const MenuBarState({
    required this.status,
    this.detail = '',
    this.canConnect = false,
    this.canDisconnect = false,
    this.tunnelUp = false,
    this.connecting = false,
  });

  final String status;

  final String detail;

  final bool canConnect;
  final bool canDisconnect;

  final bool tunnelUp;
  final bool connecting;

  Map<String, Object?> toChannel() => {
    'status': status,
    'detail': detail,
    'can_connect': canConnect,
    'can_disconnect': canDisconnect,
    'tunnel_up': tunnelUp,
    'connecting': connecting,
  };

  @override
  bool operator ==(Object other) =>
      other is MenuBarState &&
      other.status == status &&
      other.detail == detail &&
      other.canConnect == canConnect &&
      other.canDisconnect == canDisconnect &&
      other.tunnelUp == tunnelUp &&
      other.connecting == connecting;

  @override
  int get hashCode => Object.hash(
    status,
    detail,
    canConnect,
    canDisconnect,
    tunnelUp,
    connecting,
  );
}

class MenuBar {
  MenuBar({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vpn/tray');

  final MethodChannel _channel;

  static bool get supported => Platform.isMacOS || Platform.isWindows;

  MenuBarState? _last;

  void Function()? onSync;
  Future<void> Function()? onConnect;
  Future<void> Function()? onDisconnect;

  void start() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'sync':
          onSync?.call();
        case 'connect':
          await onConnect?.call();
        case 'disconnect':
          await onDisconnect?.call();
      }
      return null;
    });
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }

  Future<void> update(MenuBarState state) async {
    if (state == _last) return;
    _last = state;
    try {
      await _channel.invokeMethod<void>('update', state.toChannel());
    } on MissingPluginException {
      // No runner.
    } on PlatformException catch (e) {
      Log.e('menu bar update failed', e.message ?? e.code);
    }
  }
}
