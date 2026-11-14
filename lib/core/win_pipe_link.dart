import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'pipe_transport.dart';

const kTunnelPipe = r'\\.\pipe\Anoya.tunnel';

// Without FILE_FLAG_OVERLAPPED, WriteFile waits behind the pending ReadFile and deadlocks.
class WinPipeLink implements PipeLink {
  WinPipeLink([this.path = kTunnelPipe]);

  final String path;
  HANDLE? _handle;
  final _incoming = StreamController<List<int>>();
  Isolate? _reader;

  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    final name = path.toNativeUtf16();
    final HANDLE handle;
    try {
      final opened = CreateFile(
        PCWSTR(name),
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_NONE,
        null,
        OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,
        null,
      );
      if (!opened.value.isValid) {
        throw StateError('cannot open $path: error ${opened.error}');
      }
      handle = opened.value;
    } finally {
      calloc.free(name);
    }
    _handle = handle;
    final port = ReceivePort();
    _reader = await Isolate.spawn(_readLoop, (handle.address, port.sendPort));
    port.listen((msg) {
      if (msg == null) {
        port.close();
        _incoming.close();
      } else {
        _incoming.add(msg as Uint8List);
      }
    });
  }

  // Return values and GetLastError ignored: the VM overwrites the last error.
  static int _transfer(
    HANDLE handle,
    void Function(Pointer<OVERLAPPED> overlapped) start,
  ) {
    final overlapped = calloc<OVERLAPPED>();
    final count = calloc<Uint32>();
    final event = CreateEvent(null, true, false, null).value;
    try {
      if (!event.isValid) return -1;
      overlapped.ref.hEvent = event;
      start(overlapped);
      // A call that fails at once never signals the event; only the pipe can say it is gone.
      while (WaitForSingleObject(event, 100).value == WAIT_TIMEOUT) {
        if (PeekNamedPipe(handle, null, 0, null, null, null).value) continue;
        CancelIoEx(handle, overlapped);
        WaitForSingleObject(event, 1000);
        return -1;
      }
      if (!GetOverlappedResult(handle, overlapped, count, false).value) {
        return -1;
      }
      return count.value;
    } finally {
      if (event.isValid) CloseHandle(event);
      calloc.free(count);
      calloc.free(overlapped);
    }
  }

  static void _readLoop((int, SendPort) args) {
    final (address, port) = args;
    final handle = HANDLE(Pointer.fromAddress(address));
    const size = 64 * 1024;
    final buf = calloc<Uint8>(size);
    try {
      while (true) {
        final read = _transfer(
          handle,
          (o) => ReadFile(handle, buf, size, null, o),
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
    final handle = _handle;
    if (handle == null) return;
    final buf = calloc<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final written = _transfer(
          handle,
          (o) =>
              WriteFile(handle, buf + offset, bytes.length - offset, null, o),
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
    final handle = _handle;
    if (handle != null) {
      CloseHandle(handle);
      _handle = null;
    }
    _reader?.kill(priority: Isolate.immediate);
    _reader = null;
  }
}
