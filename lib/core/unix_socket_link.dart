import 'dart:io';

import 'pipe_transport.dart';

/// The socket the Linux tunnel service listens on. Part of the contract with
/// `cmd/tunnel-service` (main_linux.go); change them together.
const kTunnelSocket = '/run/annoyatest/tunnel.sock';

/// A client end of the service's unix socket — the Linux counterpart of
/// [WinPipeLink], with none of its trouble: dart:io speaks unix sockets
/// natively, so this is a [Socket] and nothing else.
class UnixSocketLink implements PipeLink {
  UnixSocketLink([this.path = kTunnelSocket]);

  final String path;
  Socket? _socket;

  @override
  Future<void> connect() async {
    // Absent (not installed, not running) throws a SocketException; the
    // transport logs it and knocks again.
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
