import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_version.dart';
import 'json_file_store.dart';
import 'network_extension_core.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.hwid,
    required this.os,
    required this.osVersion,
    required this.model,
  });

  final String hwid;

  final String os;

  final String osVersion;

  final String model;

  static String get userAgent =>
      appVersion.isEmpty ? kAppName : '$kAppName/$appVersion';

  Map<String, String> get headers => {
    'user-agent': userAgent,
    'x-hwid': hwid,
    if (os.isNotEmpty) 'x-device-os': os,
    if (osVersion.isNotEmpty) 'x-ver-os': osVersion,
    if (model.isNotEmpty) 'x-device-model': model,
  };

  String get label {
    final parts = [
      if (model.isNotEmpty) model,
      if (os.isNotEmpty) [os, osVersion].where((s) => s.isNotEmpty).join(' '),
    ];
    return parts.isEmpty ? 'This device' : parts.join(' · ');
  }
}

class DeviceIdentityStore {
  static final _store = JsonFileStore('device.json');
  static DeviceIdentity? _cached;

  static Future<DeviceIdentity> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    var hwid = await _store.load<String>(
      (j) => (j as Map)['hwid'] as String? ?? '',
      '',
    );
    if (!_isValidHwid(hwid)) {
      hwid = _newHwid();
      await _store.save({'hwid': hwid});
    }
    final device = await _describeDevice();
    final identity = DeviceIdentity(
      hwid: hwid,
      os: device.$1,
      osVersion: device.$2,
      model: device.$3,
    );
    _cached = identity;
    return identity;
  }

  @visibleForTesting
  static void debugCache(DeviceIdentity? identity) => _cached = identity;

  // Hex: the x-hwid convention allows only [A-Za-z0-9=-] and 10-64 chars.
  static String _newHwid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _isValidHwid(String s) =>
      s.length >= 10 &&
      s.length <= 64 &&
      RegExp(r'^[A-Za-z0-9=-]+$').hasMatch(s);

  static Future<(String, String, String)> _describeDevice() async {
    final os = Platform.isIOS
        ? 'iOS'
        : Platform.isMacOS
        ? 'macOS'
        : Platform.operatingSystem;
    final native = await NetworkExtensionCore.deviceInfo();
    if (native != null) {
      return (
        (native['os'] ?? os).toString(),
        (native['version'] ?? '').toString(),
        (native['model'] ?? '').toString(),
      );
    }
    return (os, _versionFromDartIo(), '');
  }

  static String _versionFromDartIo() {
    final raw = Platform.operatingSystemVersion;
    final m = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(raw);
    return m?.group(1) ?? '';
  }
}
