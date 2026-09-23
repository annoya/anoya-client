import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'pipe_transport.dart';

// Contract with `cmd/tunnel-service`; change them together.
const kTunnelPipe = r'\\.\pipe\Anoya.tunnel';

// FILE_FLAG_OVERLAPPED is required: on a synchronous handle a WriteFile waits
// behind the reader's pending ReadFile and the app deadlocks.
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

  // ReadFile/WriteFile return values and GetLastError are deliberately ignored:
  // the VM overwrites the last error; the OVERLAPPED wait is the reliable source.
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
      CloseHandle(_handle);
      _handle = INVALID_HANDLE_VALUE;
    }
    _reader?.kill(priority: Isolate.immediate);
    _reader = null;
  }
}
