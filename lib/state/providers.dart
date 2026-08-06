import 'dart:io' show Platform;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_prefs.dart';
import '../core/log.dart';
import '../core/network_extension_core.dart';
import '../core/vpn_core.dart';

/// The active VPN core. macOS/iOS use the system Network Extension (full
/// tunnel). Other platforms (Linux/Windows) are not supported yet — their
/// core will be added behind this same [VpnCore] seam when built.
final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS) {
    return NetworkExtensionCore();
  }
  throw UnsupportedError('No VPN core for this platform yet');
});

/// Appearance + language, persisted. The app shell watches this so switching
/// the theme repaints immediately.
class AppPrefsController extends Notifier<AppPrefs> {
  @override
  AppPrefs build() {
    // Log.enabled is already set from the same file in main(), before anything
    // could log or connect; here we only need the rest of the prefs.
    Future.microtask(() async => state = await AppPrefsStore.load());
    return const AppPrefs();
  }

  Future<void> setThemeMode(ThemeMode mode) => _save(state.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) => _save(state.copyWith(language: language));

  /// The app side of the switch takes effect immediately; the engine and the
  /// extension read it from the tunnel config, which the caller resyncs.
  Future<void> setCollectLogs(bool value) {
    Log.enabled = value;
    return _save(state.copyWith(collectLogs: value));
  }

  Future<void> _save(AppPrefs prefs) async {
    state = prefs;
    await AppPrefsStore.save(prefs);
  }
}

final appPrefsProvider = NotifierProvider<AppPrefsController, AppPrefs>(AppPrefsController.new);
