import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

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
    final stamp = DateTime.now().toUtc().toIso8601String();
    final at = '${stamp.substring(0, 23)}Z';
    final line = _context.isEmpty
        ? '$at [$level] $msg'
        : '$at [$level] $_context: $msg';
    developer.log(msg, name: 'vpn');
    if (kDebugMode) debugPrint('vpn $line');
    if (!enabled) return;
    _keep(line);
    _persist(line);
    revision.value++;
  }

  static void _keep(String line) {
    _buffer.addLast(line);
    _bufferBytes += _encodedSize(line);
    while (_buffer.length > _max) {
      _bufferBytes -= _encodedSize(_buffer.removeFirst());
    }
  }

  static const maxFileBytes = 512 * 1024;

  static RandomAccessFile? _file;
  static int _fileBytes = 0;

  static void persistTo(File file) {
    _closeFile();
    try {
      file.parent.createSync(recursive: true);
      final current = List.of(_buffer);
      _buffer.clear();
      _bufferBytes = 0;
      if (file.existsSync()) {
        final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
        for (final line in const LineSplitter().convert(text)) {
          if (line.isNotEmpty) _keep(line);
        }
      }
      current.forEach(_keep);
      _file = file.openSync(mode: FileMode.write);
      _rewriteFile();
    } on FileSystemException {
      _closeFile();
    }
    revision.value++;
  }

  static void _persist(String line) {
    final file = _file;
    if (file == null) return;
    try {
      final bytes = utf8.encode('$line\n');
      file.writeFromSync(bytes);
      _fileBytes += bytes.length;
      if (_fileBytes > maxFileBytes) _rewriteFile();
    } on FileSystemException {
      _closeFile();
    }
  }

  static void _rewriteFile() {
    final file = _file!;
    file.setPositionSync(0);
    file.truncateSync(0);
    final kept = <List<int>>[];
    var size = 0;
    for (final line in _buffer.toList().reversed) {
      final bytes = utf8.encode('$line\n');
      if (size + bytes.length > maxFileBytes ~/ 2) break;
      kept.add(bytes);
      size += bytes.length;
    }
    for (final bytes in kept.reversed) {
      file.writeFromSync(bytes);
    }
    _fileBytes = size;
  }

  static void _closeFile() {
    final file = _file;
    _file = null;
    _fileBytes = 0;
    try {
      file?.closeSync();
    } on FileSystemException {
      return;
    }
  }

  @visibleForTesting
  static void forgetForTesting() {
    _closeFile();
    _buffer.clear();
    _bufferBytes = 0;
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
    if (_file != null) {
      try {
        _rewriteFile();
      } on FileSystemException {
        _closeFile();
      }
    }
    revision.value++;
  }
}
