import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'log.dart';

class SecretStore {
  SecretStore({
    FlutterSecureStorage keyring = const FlutterSecureStorage(),
    bool? fileFallback,
    Future<Directory> Function()? directory,
  }) : _keyring = keyring,
       _fallback = fileFallback ?? Platform.isLinux,
       _directory = directory ?? getApplicationSupportDirectory;

  static final instance = SecretStore();

  static const fileName = 'secrets.json';

  final FlutterSecureStorage _keyring;
  final bool _fallback;
  final Future<Directory> Function() _directory;

  final usingFile = ValueNotifier<bool>(false);

  bool _logged = false;
  Future<void> _queue = Future.value();

  Future<String?> read(String key) async {
    if (!_fallback) return _keyring.read(key: key);
    try {
      final value = await _keyring.read(key: key);
      if (value != null) return value;
    } on PlatformException catch (e) {
      _unavailable(e);
    }
    return _serial(() async => (await _load())[key]);
  }

  Future<void> write(String key, String value) async {
    if (!_fallback) return _keyring.write(key: key, value: value);
    try {
      await _keyring.write(key: key, value: value);
      await _serial(() => _remove(key));
      return;
    } on PlatformException catch (e) {
      _unavailable(e);
    }
    await _serial(() async {
      final all = await _load();
      all[key] = value;
      await _save(all);
    });
    usingFile.value = true;
  }

  Future<void> delete(String key) async {
    if (!_fallback) return _keyring.delete(key: key);
    try {
      await _keyring.delete(key: key);
    } on PlatformException catch (e) {
      _unavailable(e);
    }
    await _serial(() => _remove(key));
  }

  void _unavailable(PlatformException e) {
    if (_logged) return;
    _logged = true;
    Log.e('secrets: no usable keyring, falling back to $fileName', e.code);
  }

  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _queue.then((_) => body());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<Map<String, String>> _load() async {
    final file = await _file();
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString());
      return {
        if (json is Map)
          for (final e in json.entries)
            if (e.value is String) '${e.key}': e.value as String,
      };
    } catch (e) {
      Log.e('secrets: $fileName unreadable', '$e');
      return {};
    }
  }

  Future<void> _save(Map<String, String> all) async {
    final dir = await (await _directory()).create(recursive: true);
    _chmod(dir.path, 0x1C0);
    final target = await _file();
    if (all.isEmpty) {
      if (await target.exists()) await target.delete();
      return;
    }
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString('');
    _chmod(tmp.path, 0x180);
    await tmp.writeAsString(jsonEncode(all), flush: true);
    await tmp.rename(target.path);
  }

  Future<void> _remove(String key) async {
    final all = await _load();
    if (all.remove(key) == null) return;
    await _save(all);
  }
}

typedef _ChmodNative = Int32 Function(Pointer<Utf8>, Uint32);
typedef _ChmodDart = int Function(Pointer<Utf8>, int);

void _chmod(String path, int mode) {
  final chmod = DynamicLibrary.process()
      .lookupFunction<_ChmodNative, _ChmodDart>('chmod');
  final p = path.toNativeUtf8();
  try {
    if (chmod(p, mode) != 0) Log.e('secrets: chmod failed', path);
  } finally {
    malloc.free(p);
  }
}
