import 'dart:io' show Platform;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/routing_prefs.dart';
import '../core/log.dart';
import '../core/network_extension_core.dart';
import '../core/pipe_transport.dart';
import '../core/unix_socket_link.dart';
import '../core/vpn_core.dart';
import '../core/win_pipe_link.dart';
import 'ready_gate.dart';

/// The VPN core. macOS/iOS drive the system Network Extension, Android a
/// VpnService in its own process, Windows and Linux a service behind a named
/// pipe or a unix socket. All speak the same control vocabulary, so one Dart
/// class serves the five — the platform difference is the transport and what
/// sits at the far end of it.
final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
    return NetworkExtensionCore();
  }
  if (Platform.isWindows) {
    return NetworkExtensionCore(transport: PipeTransport(WinPipeLink.new));
  }
  // Linux is also where CI runs the Dart tests. A transport knocks on the
  // socket from the moment it exists and keeps a retry timer alive, which a
  // widget test that never asked for a tunnel reports as a leak — so under
  // the test runner the core gets no transport: the channels have no platform
  // side there, every call answers MissingPluginException, and every caller
  // already reads that as "unavailable".
  if (Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST')) {
    return NetworkExtensionCore(transport: PipeTransport(UnixSocketLink.new));
  }
  return NetworkExtensionCore();
});

/// Appearance + language, persisted. The app shell watches this so switching
/// the theme repaints immediately.
class AppPrefsController extends Notifier<AppPrefs> with ReadyGate {
  @override
  AppPrefs build() {
    // Log.enabled is already set from the same file in main(), before anything
    // could log or connect; here we only need the rest of the prefs.
    ready = AppPrefsStore.load().then((v) {
      state = v;
    });
    return const AppPrefs();
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _save((p) => p.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) =>
      _save((p) => p.copyWith(language: language));

  /// The app side of the switch takes effect immediately; the engine and the
  /// extension read it from the tunnel config, which the caller resyncs.
  Future<void> setCollectLogs(bool value) {
    Log.enabled = value;
    return _save((p) => p.copyWith(collectLogs: value));
  }

  Future<void> _save(AppPrefs Function(AppPrefs) change) async {
    await ready;
    final prefs = change(state);
    state = prefs;
    await AppPrefsStore.save(prefs);
  }
}

final appPrefsProvider = NotifierProvider<AppPrefsController, AppPrefs>(
  AppPrefsController.new,
);

/// The device's own routing preferences: one owner for the readers on the DNS
/// screens and the writers on the settings and geo screens. Same shape as
/// [AppPrefsController]; it used to be a FutureProvider that two screens
/// bypassed with their own copy of the file, re-read after every pop.
class RoutingPrefsController extends Notifier<RoutingPrefs> with ReadyGate {
  @override
  RoutingPrefs build() {
    ready = reload();
    return const RoutingPrefs();
  }

  /// Re-reads the file. [GeoStore] stamps `geoUpdatedAt` on its own after a
  /// download, so the screen that shows it asks for a fresh copy.
  Future<void> reload() async {
    final prefs = await RoutingPrefsStore.load();
    if (ref.mounted) state = prefs;
  }

  /// Read-modify-write against the file, not against [state]: GeoStore stamps
  /// geoUpdatedAt into the same file on its own, and a change computed from
  /// the snapshot taken at startup would save that stamp away — after which
  /// the next launch downloads the databases again.
  Future<void> update(RoutingPrefs Function(RoutingPrefs) change) async {
    await ready;
    final prefs = change(await RoutingPrefsStore.load());
    state = prefs;
    await RoutingPrefsStore.save(prefs);
  }
}

final routingPrefsProvider =
    NotifierProvider<RoutingPrefsController, RoutingPrefs>(
      RoutingPrefsController.new,
    );
