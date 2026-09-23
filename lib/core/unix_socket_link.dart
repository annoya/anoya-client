import 'dart:io';

import 'pipe_transport.dart';

// Contract with `cmd/tunnel-service` (main_linux.go); change them together.
const kTunnelSocket = '/run/annoyatest/tunnel.sock';

class UnixSocketLink implements PipeLink {
  UnixSocketLink([this.path = kTunnelSocket]);

  final String path;
  Socket? _socket;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
  }

  @override
  Stream<List<int>> get incoming => _socket!;

  @override
  void write(List<int> bytes) => _socket?.add(bytes);

  @override
  void close() {
    _socket?.destroy();
    _socket = null;
  }
}
