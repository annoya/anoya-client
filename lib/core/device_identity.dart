import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'json_file_store.dart';
import 'network_extension_core.dart';

/// What this installation tells a subscription panel about itself.
///
/// Panels that enforce a device limit (Remnawave and the panels that copied its
/// convention) identify a device by an `x-hwid` header, with the OS and model
/// as optional detail. Without it such a panel answers 404, so this is not a
/// nicety — it is the difference between a subscription that loads and one that
/// silently stops.
class DeviceIdentity {
  const DeviceIdentity({
    required this.hwid,
    required this.os,
    required this.osVersion,
    required this.model,
  });

  /// Stable per-installation id. See [_newHwid] for what it is and is not.
  final String hwid;

  /// "iOS" / "macOS".
  final String os;

  /// e.g. "18.0".
  final String osVersion;

  /// Hardware model, e.g. "iPhone16,1". Empty when the platform did not say.
  final String model;

  /// The headers a subscription request carries. Only `x-hwid` is required by
  /// the convention; the rest exist so the entry in the provider's panel is
  /// recognisable as *this* device instead of an opaque id.
  Map<String, String> get headers => {
        'x-hwid': hwid,
        if (os.isNotEmpty) 'x-device-os': os,
        if (osVersion.isNotEmpty) 'x-ver-os': osVersion,
        if (model.isNotEmpty) 'x-device-model': model,
      };

  /// How this device reads in the app, e.g. "iPhone16,1 · iOS 18.0".
  String get label {
    final parts = [
      if (model.isNotEmpty) model,
      if (os.isNotEmpty) [os, osVersion].where((s) => s.isNotEmpty).join(' '),
    ];
    return parts.isEmpty ? 'This device' : parts.join(' · ');
  }
}

/// Loads (creating once) the identity this installation presents to panels.
class DeviceIdentityStore {
  static final _store = JsonFileStore('device.json');
  static DeviceIdentity? _cached;

  /// Cached after the first read: it is needed on every subscription request,
  /// and it never changes within a run.
  static Future<DeviceIdentity> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    var hwid = await _store.load<String>((j) => (j as Map)['hwid'] as String? ?? '', '');
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

  /// Forgets the cached value (tests, and a future "reset identity" action).
  static void forget() => _cached = null;

  @visibleForTesting
  static void debugCache(DeviceIdentity? identity) => _cached = identity;

  /// A random id, not a hardware serial.
  ///
  /// The panel needs exactly one thing — to tell devices apart — and a random
  /// number does that. A hardware identifier would additionally hand every
  /// provider the same key, letting unrelated ones recognise the same device;
  /// that is a cost with no matching benefit to anyone but them.
  ///
  /// Hex, because the convention allows only Latin letters, digits, `=` and `-`
  /// (so base64url's `_` is out), and 32 characters sits comfortably inside the
  /// 10–64 the convention requires.
  static String _newHwid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _isValidHwid(String s) =>
      s.length >= 10 && s.length <= 64 && RegExp(r'^[A-Za-z0-9=-]+$').hasMatch(s);

  /// (os, version, model). Falls back to what dart:io knows when the platform
  /// side is unavailable — the model is optional, so a missing one costs
  /// recognisability, not function.
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

  /// dart:io reports "Version 18.0 (Build 22A3354)"; keep the number.
  static String _versionFromDartIo() {
    final raw = Platform.operatingSystemVersion;
    final m = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(raw);
    return m?.group(1) ?? '';
  }
}

/// Test seam: pins the identity so a test does not depend on the host.
@visibleForTesting
void debugSetDeviceIdentity(DeviceIdentity? identity) =>
    DeviceIdentityStore.debugCache(identity);
