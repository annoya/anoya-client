import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'log.dart';

/// What the menu bar item (macOS) or tray icon (Windows) shows, in the words it
/// shows them.
///
/// The text is composed here rather than in Swift or C++ so the menu says the
/// same thing as the home screen on every platform — the platform side owns
/// the surface, not the vocabulary.
class MenuBarState {
  const MenuBarState({
    required this.status,
    this.detail = '',
    this.canConnect = false,
    this.canDisconnect = false,
    this.tunnelUp = false,
    this.connecting = false,
  });

  /// First line: what the tunnel is doing, and where.
  final String status;

  /// Second line: session time and which configuration. Empty when there is
  /// nothing to add — a blank line in a menu reads as a bug.
  final String detail;

  final bool canConnect;
  final bool canDisconnect;

  /// Drives the icon and the note under Quit. Both are about a live tunnel,
  /// which is not the same as "the app thinks it is connected".
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
  int get hashCode =>
      Object.hash(status, detail, canConnect, canDisconnect, tunnelUp, connecting);
}

/// The bridge to the `NSStatusItem` on macOS and the notification-area icon
/// on Windows (`windows/runner/tray_icon.cpp`). A no-op everywhere else, so
/// callers need no platform checks of their own.
///
/// Show / hide / quit never reach this class: they are window-server actions
/// and are handled natively, without waiting on the isolate. What crosses the
/// channel is state going out, and connect / disconnect coming in — those the
/// app has to decide (a managed profile refreshes before it connects, and a
/// failure has to be reported), so the platform only asks.
class MenuBar {
  MenuBar({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vpn/tray');

  final MethodChannel _channel;

  /// True where a menu bar or a tray exists at all. iOS and Android have
  /// neither, and the tests run on a host that pretends to be the former.
  static bool get supported => Platform.isMacOS || Platform.isWindows;

  MenuBarState? _last;

  /// Called when the platform side needs current state — it asks every time the
  /// menu opens, because the session clock runs here.
  void Function()? onSync;
  Future<void> Function()? onConnect;
  Future<void> Function()? onDisconnect;

  void start() {
    if (!supported) return;
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

  /// Stops answering the platform side. The status item itself belongs to the
  /// runner and outlives the isolate's providers.
  void dispose() {
    if (!supported) return;
    _channel.setMethodCallHandler(null);
  }

  /// Pushes state, skipping a push that would change nothing. The menu asks on
  /// every open, so this runs often enough for the difference to matter.
  Future<void> update(MenuBarState state) async {
    if (!supported || state == _last) return;
    _last = state;
    try {
      await _channel.invokeMethod<void>('update', state.toChannel());
    } on MissingPluginException {
      // No platform side (an older build, or a host without the runner).
    } on PlatformException catch (e) {
      Log.e('menu bar update failed', e.message ?? e.code);
    }
  }
}
