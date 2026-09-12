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
/// writes are short and stay on the caller's side.
///
/// The handle is opened with `FILE_FLAG_OVERLAPPED`, and that is not optional:
/// on a synchronous handle Windows serializes every operation on the file
/// object, so a `WriteFile` on the UI thread waits behind the reader's pending
/// `ReadFile` — which waits for the service, which waits for the request the
/// UI is trying to write. The first request of a session deadlocked the app
/// before its window ever showed. With overlapped I/O each call carries its own
/// `OVERLAPPED` and event and the two directions no longer queue on each other;
/// each side still waits for its own completion, so the callers see the same
/// blocking behaviour as before.
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
      _handle = CreateFile(
        name,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,
        NULL,
      );
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

  /// Issues one overlapped operation and waits for it to finish. Returns the
  /// number of bytes transferred; 0 or -1 means the operation failed (the pipe
  /// is gone, or the handle was closed under it) and the caller stops.
  ///
  /// The return value of ReadFile/WriteFile is deliberately not consulted, and
  /// neither is `GetLastError`: between the Win32 call returning and Dart
  /// reading the thread's last error, the VM makes Win32 calls of its own and
  /// overwrites it. Taking a pending operation for a failed one and freeing its
  /// buffers while the kernel still owns them corrupted the heap. Waiting on
  /// the OVERLAPPED is the one reliable source: pending or completed, the
  /// result comes from there, and a call that failed outright never marked the
  /// struct pending, so the wait returns at once with zero bytes.
  static int _transfer(
    int handle,
    int Function(Pointer<OVERLAPPED> overlapped) start,
  ) {
    final overlapped = calloc<OVERLAPPED>();
    final count = calloc<Uint32>();
    final event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    try {
      if (event == NULL) return -1;
      overlapped.ref.hEvent = event;
      start(overlapped);
      if (GetOverlappedResult(handle, overlapped, count, TRUE) == 0) return -1;
      return count.value;
    } finally {
      if (event != NULL) CloseHandle(event);
      calloc.free(count);
      calloc.free(overlapped);
    }
  }

  /// Reads until the pipe breaks. Runs in its own isolate; a null message is
  /// the end.
  static void _readLoop((int, SendPort) args) {
    final (handle, port) = args;
    const size = 64 * 1024;
    final buf = calloc<Uint8>(size);
    try {
      while (true) {
        final read = _transfer(
          handle,
          (o) => ReadFile(handle, buf, size, nullptr, o),
        );
        if (read <= 0) break;
        port.send(Uint8List.fromList(buf.asTypedList(read)));
      }
    } finally {
      calloc.free(buf);
      port.send(null);
    }
  }

  @override
  void write(List<int> bytes) {
    if (_handle == INVALID_HANDLE_VALUE) return;
    final buf = calloc<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final written = _transfer(
          _handle,
          (o) => WriteFile(
            _handle,
            buf + offset,
            bytes.length - offset,
            nullptr,
            o,
          ),
        );
        if (written <= 0) break;
        offset += written;
      }
    } finally {
      calloc.free(buf);
    }
  }

  @override
  void close() {
    if (_handle != INVALID_HANDLE_VALUE) {
      // Closing the handle fails the reader's pending ReadFile, which ends its
      // loop; the kill below is for the case where it is between reads.
      CloseHandle(_handle);
      _handle = INVALID_HANDLE_VALUE;
    }
    _reader?.kill(priority: Isolate.immediate);
    _reader = null;
  }
}
