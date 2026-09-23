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
    _add('ERROR', error != null ? '$msg: $error' : msg);
    developer.log(msg, name: 'vpn', level: 1000, error: error, stackTrace: st);
  }

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

  static void _add(String level, String msg) {
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
