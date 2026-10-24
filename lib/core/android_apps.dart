import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'log.dart';
import 'network_extension_core.dart';
import 'platform_support.dart';

class AndroidApp {
  const AndroidApp({required this.package, required this.label, this.icon});

  final String package;
  final String label;
  final Uint8List? icon;
}

class AndroidApps {
  AndroidApps._();

  static Future<List<AndroidApp>>? _installed;

  static Future<List<AndroidApp>> installed({bool refresh = false}) {
    if (refresh || _installed == null) {
      _installed = _load().then((apps) {
        if (apps.isEmpty) _installed = null;
        return apps;
      });
    }
    return _installed!;
  }

  @visibleForTesting
  static void forgetForTesting() => _installed = null;

  static Future<List<AndroidApp>> _load() async {
    try {
      final raw =
          await NetworkExtensionCore.control.invoke<List<dynamic>>(
            'installed_apps',
          ) ??
          const [];
      final apps = [
        for (final a in raw.whereType<Map<dynamic, dynamic>>())
          AndroidApp(
            package: '${a['package']}',
            label: '${a['label']}',
            icon: a['icon'] is Uint8List ? a['icon'] as Uint8List : null,
          ),
      ];
      apps.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return apps;
    } on PlatformException catch (e) {
      Log.e('installed apps unavailable', e.message ?? e.code);
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<List<String>> excluded() async {
    try {
      final raw = await NetworkExtensionCore.control.invoke<List<dynamic>>(
        'excluded_apps',
      );
      return [for (final p in raw ?? const []) '$p'];
    } on PlatformException catch (e) {
      Log.e('apps outside the VPN unreadable', e.message ?? e.code);
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<void> setExcluded(List<String> packages) => NetworkExtensionCore
      .control
      .invoke<void>('set_excluded_apps', {'packages': packages});

  static Future<List<String>?> excludedInUse() async {
    try {
      final raw = await NetworkExtensionCore.control.invoke<List<dynamic>>(
        'excluded_apps_in_use',
      );
      return raw == null ? null : [for (final p in raw) '$p'];
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> restartTunnel() =>
      NetworkExtensionCore.control.invoke<void>('restart_tunnel');
}

Future<void> loadAndroidSdk() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final info = await NetworkExtensionCore.deviceInfo();
  androidSdk = int.tryParse(info?['sdk'] ?? '') ?? 0;
}
