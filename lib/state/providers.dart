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

final vpnCoreProvider = Provider<VpnCore>((_) {
  if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
    return NetworkExtensionCore();
  }
  if (Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST')) {
    return NetworkExtensionCore(transport: PipeTransport(WinPipeLink.new));
  }
  if (Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST')) {
    return NetworkExtensionCore(transport: PipeTransport(UnixSocketLink.new));
  }
  return NetworkExtensionCore();
});

class AppPrefsController extends Notifier<AppPrefs> with ReadyGate {
  @override
  AppPrefs build() {
    ready = AppPrefsStore.load().then((v) {
      state = v;
    });
    return const AppPrefs();
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _save((p) => p.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) =>
      _save((p) => p.copyWith(language: language));

  Future<void> setCollectLogs(bool value) {
    Log.enabled = value;
    return _save((p) => p.copyWith(collectLogs: value));
  }

  Future<void> replace(AppPrefs prefs) {
    Log.enabled = prefs.collectLogs;
    return _save((_) => prefs);
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

class RoutingPrefsController extends Notifier<RoutingPrefs> with ReadyGate {
  @override
  RoutingPrefs build() {
    ready = reload();
    return const RoutingPrefs();
  }

  Future<void> reload() async {
    final prefs = await RoutingPrefsStore.load();
    if (ref.mounted) state = prefs;
  }

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
