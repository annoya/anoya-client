import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'pipe_transport.dart';

/// The pipe the tunnel service listens on. Part of the contract with
/// `cmd/tunnel-service`; change them together.
const kTunnelPipe = r'\\.\pipe\AnnoyaTest.tunnel';

/// A client end of the service's named pipe, through kernel32.
///
/// Dart's sockets do not speak named pipes, so this is the Win32 file API on a
/// pipe path. Reads block, and a blocked read cannot share the isolate with the
/// UI — so they run in an isolate of their own, which posts each chunk back;
/// writes are short and stay on the caller's side. A duplex pipe carries the
/// two directions independently, which is what makes one handle safe to read
/// on one thread and write on another.
///
/// Windows only: every call here is into kernel32, and the class is constructed
/// only behind a `Platform.isWindows` check.
class WinPipeLink implements PipeLink {
  WinPipeLink([this.path = kTunnelPipe]);

  final String path;
  int _handle = INVALID_HANDLE_VALUE;
  final _incoming = StreamController<List<int>>();
  Isolate? _reader;

  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    final name = path.toNativeUtf16();
    try {
      _handle = CreateFile(name, GENERIC_READ | GENERIC_WRITE, 0, nullptr,
          OPEN_EXISTING, 0, NULL);
      if (_handle == INVALID_HANDLE_VALUE) {
        // Absent (not installed, not running) or busy (an instance still being
        // set up for another client): either way the transport knocks again.
        throw StateError('cannot open $path: error ${GetLastError()}');
      }
    } finally {
      calloc.free(name);
    }
    final port = ReceivePort();
    _reader = await Isolate.spawn(_readLoop, (_handle, port.sendPort));
    port.listen((msg) {
      if (msg == null) {
        port.close();
        _incoming.close();
      } else {
        _incoming.add(msg as Uint8List);
      }
    });
  }

  /// Blocking reads until the pipe breaks. Runs in its own isolate; a null
  /// message is the end.
  static void _readLoop((int, SendPort) args) {
    final (handle, port) = args;
    const size = 64 * 1024;
    final buf = calloc<Uint8>(size);
    final read = calloc<Uint32>();
    try {
      while (true) {
        final ok = ReadFile(handle, buf, size, read, nullptr);
        if (ok == 0 || read.value == 0) break;
        port.send(Uint8List.fromList(buf.asTypedList(read.value)));
      }
    } finally {
      calloc.free(buf);
      calloc.free(read);
      port.send(null);
    }
  }

  @override
  void write(List<int> bytes) {
    if (_handle == INVALID_HANDLE_VALUE) return;
    final buf = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final ok = WriteFile(_handle, buf + offset, bytes.length - offset, written, nullptr);
        if (ok == 0) break;
        offset += written.value;
      }
    } finally {
      calloc.free(buf);
      calloc.free(written);
    }
  }

  @override
  void close() {
    if (_handle != INVALID_HANDLE_VALUE) {
      CloseHandle(_handle);
      _handle = INVALID_HANDLE_VALUE;
    }
    _reader?.kill(priority: Isolate.immediate);
    _reader = null;
  }
}
