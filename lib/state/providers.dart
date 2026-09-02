import 'dart:io' show Platform;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/routing_prefs.dart';
import '../core/log.dart';
import '../core/network_extension_core.dart';
import '../core/vpn_core.dart';
import 'ready_gate.dart';

/// The VPN core. macOS/iOS drive the system Network Extension; Android drives
/// a VpnService with the engine in-process. Both speak the same "vpn/control"
/// channel contract, so one Dart class serves all three — the platform
/// difference lives entirely on the native side.
final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
    return NetworkExtensionCore();
  }
  throw UnsupportedError('No VPN core for this platform yet');
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

  Future<void> setThemeMode(ThemeMode mode) => _save((p) => p.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) => _save((p) => p.copyWith(language: language));

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

final appPrefsProvider = NotifierProvider<AppPrefsController, AppPrefs>(AppPrefsController.new);

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

  Future<void> update(RoutingPrefs Function(RoutingPrefs) change) async {
    await ready;
    final prefs = change(state);
    state = prefs;
    await RoutingPrefsStore.save(prefs);
  }
}

final routingPrefsProvider =
    NotifierProvider<RoutingPrefsController, RoutingPrefs>(RoutingPrefsController.new);
