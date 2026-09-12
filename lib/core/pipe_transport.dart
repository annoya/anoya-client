import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'control_transport.dart';
import 'log.dart';

/// One byte-stream connection to the tunnel service. [WinPipeLink] is the
/// named pipe; tests substitute a fake.
abstract class PipeLink {
  /// Opens the connection. Throws when the service is not there to answer.
  Future<void> connect();

  /// Bytes from the service. Ends when the service hangs up.
  Stream<List<int>> get incoming;

  void write(List<int> bytes);

  void close();
}

/// The wire to the Windows tunnel service: one JSON object per line each way.
///
/// The app sends `{"id","method","args"}` and reads `{"id","result","error"}`
/// back, matched by id; the service pushes `{"event":"status","status"}` in
/// between, and the first thing a fresh connection carries is the current
/// status — the app may have been opened over a tunnel the service brought up
/// at boot. Mirrors `service.go` on the other end.
///
/// The service can be absent (not installed, stopped, still starting) and the
/// app has to say so without breaking: a request then fails with
/// `service_unavailable`, the status reads disconnected, and the transport
/// keeps knocking every [retryDelay] so the moment the service appears the app
/// picks up its state.
class PipeTransport implements ControlTransport {
  PipeTransport(this._open, {this.retryDelay = const Duration(seconds: 3)}) {
    unawaited(_connect());
  }

  final PipeLink Function() _open;
  final Duration retryDelay;

  PipeLink? _link;
  Future<void>? _connecting;
  Timer? _retry;
  bool _disposed = false;

  int _seq = 0;
  final _pending = <int, Completer<Object?>>{};
  final _status = StreamController<String?>.broadcast();
  final _partial = <int>[];

  @override
  Stream<String?> get statusEvents => _status.stream;

  @override
  Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
    final link = _link ?? await _ensureLink();
    final id = ++_seq;
    final done = Completer<Object?>();
    _pending[id] = done;
    link.write(
      utf8.encode(
        '${jsonEncode({'id': id, 'method': method, 'args': args ?? {}})}\n',
      ),
    );
    return (await done.future) as T?;
  }

  Future<PipeLink> _ensureLink() async {
    final link = _link;
    if (link != null) return link;
    await _connect();
    final now = _link;
    if (now == null) {
      throw PlatformException(
        code: 'service_unavailable',
        message: 'the tunnel service is not running',
      );
    }
    return now;
  }

  Future<void> _connect() {
    if (_disposed || _link != null) return Future.value();
    return _connecting ??= () async {
      final link = _open();
      try {
        await link.connect();
      } catch (e) {
        Log.e('tunnel service unreachable', e);
        _emit('disconnected');
        _scheduleRetry();
        return;
      } finally {
        _connecting = null;
      }
      if (_disposed) {
        link.close();
        return;
      }
      _link = link;
      _partial.clear();
      link.incoming.listen(
        _onBytes,
        onDone: _dropLink,
        onError: (Object e) {
          Log.e('tunnel service link failed', e);
          _dropLink();
        },
      );
    }();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(retryDelay, () => unawaited(_connect()));
  }

  /// The service hung up — stopped, crashed, or upgraded under us. Every
  /// caller still waiting gets an answer, the status says what the tunnel is
  /// now, and the next knock is scheduled.
  void _dropLink() {
    final link = _link;
    if (link == null) return;
    _link = null;
    link.close();
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final c in waiting) {
      c.completeError(
        PlatformException(
          code: 'service_disconnected',
          message: 'the tunnel service went away',
        ),
      );
    }
    _emit('disconnected');
    _scheduleRetry();
  }

  void _emit(String? status) {
    if (!_status.isClosed) _status.add(status);
  }

  void _onBytes(List<int> bytes) {
    _partial.addAll(bytes);
    var start = 0;
    for (var i = 0; i < _partial.length; i++) {
      if (_partial[i] != 0x0a) continue;
      if (i > start) _onLine(utf8.decode(_partial.sublist(start, i)));
      start = i + 1;
    }
    if (start > 0) _partial.removeRange(0, start);
  }

  void _onLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      Log.e('tunnel service sent a line that is not JSON');
      return;
    }
    if (decoded is! Map) return;
    if (decoded['event'] == 'status') {
      _emit(decoded['status'] as String?);
      return;
    }
    final id = decoded['id'];
    final done = id is int ? _pending.remove(id) : null;
    if (done == null) return;
    final error = decoded['error'];
    if (error is String && error.isNotEmpty) {
      done.completeError(
        PlatformException(code: 'service_error', message: error),
      );
    } else {
      done.complete(decoded['result']);
    }
  }

  /// For tests: stops retrying and drops the connection.
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _dropLink();
    _status.close();
  }
}
