import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'geo_store.dart';
import 'log.dart';
import 'network_extension_core.dart';

class GeositeCategory {
  const GeositeCategory(this.name, this.domainCount);

  final String name;
  final int domainCount;
}

class GeositeIndex {
  static const _cacheFile = 'geosite-index.json';

  static Future<List<GeositeCategory>> load() async {
    final dirPath = await NetworkExtensionCore.sharedDir();
    if (dirPath == null) return const [];
    final dat = File('$dirPath/${GeoStore.geositeFile}');
    if (!await dat.exists()) return const [];
    final stat = await dat.stat();
    final key = '${stat.size}:${stat.modified.millisecondsSinceEpoch}';

    final cache = File('$dirPath/$_cacheFile');
    final cached = await _readCache(cache, key);
    if (cached != null) return cached;

    final sw = Stopwatch()..start();
    final path = dat.path;
    final list = await Isolate.run(() => scan(File(path).readAsBytesSync()));
    Log.i(
      'geosite index: ${list.length} categories in ${sw.elapsedMilliseconds} ms',
    );
    await _writeCache(cache, key, list);
    return list;
  }

  static List<GeositeCategory> scan(Uint8List bytes) {
    final out = <GeositeCategory>[];
    final r = _Reader(bytes);
    try {
      while (!r.done) {
        final tag = r.varint();
        if (tag >> 3 == 1 && tag & 7 == 2) {
          out.add(_entry(r.slice(r.varint())));
        } else {
          r.skip(tag);
        }
      }
    } catch (e) {
      Log.e('geosite index: scan stopped early', '$e');
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  static GeositeCategory _entry(_Reader r) {
    var name = '';
    var domains = 0;
    while (!r.done) {
      final tag = r.varint();
      switch (tag >> 3) {
        case 1 when tag & 7 == 2:
          name = utf8
              .decode(r.bytes(r.varint()), allowMalformed: true)
              .toLowerCase();
        case 2 when tag & 7 == 2:
          domains++;
          r.bytes(r.varint());
        default:
          r.skip(tag);
      }
    }
    return GeositeCategory(name, domains);
  }

  static Future<List<GeositeCategory>?> _readCache(
    File cache,
    String datKey,
  ) async {
    try {
      if (!await cache.exists()) return null;
      final j = jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
      if (j['dat_key'] != datKey) return null;
      return [
        for (final e in j['categories'] as List)
          GeositeCategory(e['n'] as String, e['d'] as int),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(
    File cache,
    String datKey,
    List<GeositeCategory> list,
  ) async {
    try {
      await cache.writeAsString(
        jsonEncode({
          'dat_key': datKey,
          'categories': [
            for (final c in list) {'n': c.name, 'd': c.domainCount},
          ],
        }),
      );
    } catch (e) {
      Log.e('geosite index: cache write failed', '$e');
    }
  }
}

class _Reader {
  _Reader(this._b);

  final Uint8List _b;
  int _pos = 0;

  bool get done => _pos >= _b.length;

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_pos >= _b.length) throw const FormatException('varint past end');
      final byte = _b[_pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
      if (shift > 63) throw const FormatException('varint too long');
    }
  }

  Uint8List bytes(int n) {
    if (n < 0 || _pos + n > _b.length) {
      throw const FormatException('slice past end');
    }
    final v = Uint8List.sublistView(_b, _pos, _pos + n);
    _pos += n;
    return v;
  }

  _Reader slice(int n) => _Reader(bytes(n));

  void skip(int tag) {
    switch (tag & 7) {
      case 0:
        varint();
      case 1:
        bytes(8);
      case 2:
        bytes(varint());
      case 5:
        bytes(4);
      default:
        throw FormatException('unsupported wire type ${tag & 7}');
    }
  }
}
