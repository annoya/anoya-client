import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// App logger. Writes to the Dart developer console AND keeps the last N lines
/// in memory so the in-app "App log" view can show them.
class Log {
  Log._();

  static const _max = 1000;
  static final ListQueue<String> _buffer = ListQueue<String>();

  /// Sum of the buffered lines' encoded sizes, kept as they are added and
  /// removed. The Logs screen reads the total on every build, and joining a
  /// thousand lines per frame to measure them is work with no result.
  static int _bufferBytes = 0;

  /// Bumps whenever a line is added, so log views can rebuild live.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Mirrors the "Collect logs" preference. It governs the in-app buffer (what
  /// the log views show and the archive carries), not the console: developing
  /// against your own build would be impossible if the switch also muted that.
  /// Off keeps the buffer intact too — the user stopped recording, not history.
  static bool enabled = true;

  static void i(String msg) => _add('INFO', msg);

  static void e(String msg, [Object? error, StackTrace? st]) {
    _add('ERROR', error != null ? '$msg: $error' : msg);
    developer.log(msg, name: 'vpn', level: 1000, error: error, stackTrace: st);
  }

  static void _add(String level, String msg) {
    final line = '[$level] $msg';
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

  static List<String> lines() => _buffer.toList();
  static String dump() => _buffer.join('\n');

  /// Size of what [dump] would produce, in bytes. Real bytes, not code units:
  /// the number is shown next to a file size, and a log full of Cyrillic would
  /// otherwise read as half its actual size.
  static int get sizeBytes =>
      _buffer.isEmpty ? 0 : _bufferBytes - _separatorBytes;

  /// dump() joins with newlines, so the last line has no separator after it.
  static const _separatorBytes = 1;

  static int _encodedSize(String line) => utf8.encode(line).length + _separatorBytes;

  static void clear() {
    _buffer.clear();
    _bufferBytes = 0;
    revision.value++;
  }
}
