import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';

import 'log.dart';
import 'secret_store.dart';

class JsonFileStore {
  JsonFileStore(this.filename);

  final String filename;

  @visibleForTesting
  static int pending = 0;

  static final _saved = StreamController<String>.broadcast(sync: true);

  static Stream<String> get saved => _saved.stream;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$filename');
  }

  Future<T> load<T>(T Function(dynamic json) decode, T fallback) async {
    pending++;
    try {
      final f = await _file();
      if (!await f.exists()) return fallback;
      return decode(jsonDecode(await f.readAsString()));
    } catch (e) {
      Log.e('$filename: could not load', '$e');
      return fallback;
    } finally {
      pending--;
    }
  }

  int _writeSeq = 0;
  int _committedSeq = -1;

  Future<void> save(Object json) async {
    final seq = _writeSeq++;
    pending++;
    try {
      await _write(seq, json);
    } finally {
      pending--;
    }
  }

  Future<void> _write(int seq, Object json) async {
    final f = await _file();
    final tmp = File('${f.path}.$seq.tmp');
    try {
      await tmp.writeAsString(jsonEncode(json), flush: true);
      if (seq < _committedSeq) {
        await tmp.delete();
        return;
      }
      tmp.renameSync(f.path);
      _committedSeq = seq;
      _saved.add(filename);
    } catch (e) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

class SecureJsonStore {
  SecureJsonStore(this.name);

  final String name;

  bool _unreadable = false;
  Future<void> _queue = Future.value();

  Future<T> load<T>(T Function(dynamic json) decode, T fallback) async {
    final String? raw;
    try {
      raw = await SecretStore.instance.read(name);
    } catch (e) {
      _unreadable = true;
      Log.e('$name: secure storage unreadable, not saving over it', '$e');
      return fallback;
    }
    _unreadable = false;
    if (raw == null) return fallback;
    try {
      return decode(jsonDecode(raw));
    } catch (e) {
      Log.e('$name: could not load', '$e');
      return fallback;
    }
  }

  Future<void> save(Object json) {
    final run = _queue.then((_) async {
      if (_unreadable) {
        throw StateError('$name was not readable; refusing to overwrite it');
      }
      await SecretStore.instance.write(name, jsonEncode(json));
      JsonFileStore._saved.add(name);
    });
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }
}

List<T> decodeListLenient<T>(
  dynamic json,
  String what,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (json is! List) return [];
  final out = <T>[];
  for (final e in json) {
    try {
      out.add(fromJson(Map<String, dynamic>.from(e as Map)));
    } catch (err) {
      Log.e('$what: skipped a damaged entry', '$err');
    }
  }
  return out;
}
