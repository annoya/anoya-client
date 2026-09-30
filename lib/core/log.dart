import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class Log {
  Log._();

  static const _max = 1000;
  static final ListQueue<String> _buffer = ListQueue<String>();

  static int _bufferBytes = 0;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool enabled = true;

  static void i(String msg) => _add('INFO', msg);

  static void e(String msg, [Object? error, StackTrace? st]) {
    _add('ERROR', error != null ? '$msg: ${_firstLine('$error')}' : msg);
    developer.log(msg, name: 'vpn', level: 1000, error: error, stackTrace: st);
  }

  static String _firstLine(String s) {
    final nl = s.indexOf('\n');
    return nl < 0 ? s : s.substring(0, nl);
  }

  static final _url = RegExp(r"""[A-Za-z][A-Za-z0-9+.\-]*://[^\s"'<>]+""");

  @visibleForTesting
  static String redact(String s) => s.replaceAllMapped(_url, (m) {
    final url = m[0]!;
    final scheme = url.substring(0, url.indexOf('://'));
    final uri = Uri.tryParse(url);
    final named =
        uri != null &&
        (uri.host.contains('.') ||
            uri.host.contains(':') ||
            uri.host == 'localhost');
    if (!named) return '$scheme://…';
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    final more =
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment;
    return '$scheme://$host$port${more ? '/…' : ''}';
  });

  static String _context = '';

  static T within<T>(String label, T Function() body) {
    final previous = _context;
    _context = label.isEmpty ? previous : label;
    try {
      return body();
    } finally {
      _context = previous;
    }
  }

  static void _add(String level, String raw) {
    final msg = redact(raw);
    final line = _context.isEmpty
        ? '[$level] $msg'
        : '[$level] $_context: $msg';
    developer.log(msg, name: 'vpn');
    if (kDebugMode) debugPrint('vpn $line');
    if (!enabled) return;
    _buffer.addLast(line);
    _bufferBytes += _encodedSize(line);
    while (_buffer.length > _max) {
      _bufferBytes -= _encodedSize(_buffer.removeFirst());
    }
    revision.value++;
  }

  static String dump() => _buffer.join('\n');

  static int get sizeBytes =>
      _buffer.isEmpty ? 0 : _bufferBytes - _separatorBytes;

  static const _separatorBytes = 1;

  static int _encodedSize(String line) =>
      utf8.encode(line).length + _separatorBytes;

  static void clear() {
    _buffer.clear();
    _bufferBytes = 0;
    revision.value++;
  }
}
