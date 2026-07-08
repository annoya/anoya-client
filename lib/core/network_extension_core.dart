import 'dart:async';

import 'package:flutter/services.dart';

import 'log.dart';
import 'mihomo_tun_config.dart';
import 'norm_config.dart';
import 'vpn_core.dart';

/// NetworkExtensionCore drives a real system VPN via the macOS/iOS
/// NEPacketTunnelProvider extension. The mihomo engine runs inside the
/// extension (MihomoCore.xcframework); this class only sends the rendered
/// config and start/stop commands over a MethodChannel, and reflects status
/// from an EventChannel. The VpnCore seam is unchanged, so screens/state don't
/// care which core is active.
///
/// Note: the connect/disconnect path deliberately does NOT read the shared log
/// container — doing so from the host triggers a macOS "access data from other
/// apps" prompt. Logs are viewed on demand in the Logs screen instead.
class NetworkExtensionCore implements VpnCore {
  NetworkExtensionCore() {
    _statusStream = _statusEvents
        .receiveBroadcastStream()
        .map((e) => _mapStatus(e as String?))
        .asBroadcastStream();
    _sub = _statusStream.listen((s) => _status = s);
  }

  static const _control = MethodChannel('vpn/control');
  static const _statusEvents = EventChannel('vpn/status');

  late final Stream<VpnStatus> _statusStream;
  StreamSubscription<VpnStatus>? _sub;
  NormConfig? _config;
  VpnStatus _status = VpnStatus.disconnected;

  @override
  VpnStatus get status => _status;

  @override
  Stream<VpnStatus> statusStream() => _statusStream;

  @override
  Stream<VpnStats> statsStream() => const Stream.empty();

  @override
  Future<void> load(NormConfig config) async {
    _config = config;
  }

  @override
  Future<void> connect(String locationId) async {
    final config = _config;
    if (config == null) throw StateError('no config loaded');
    final location = config.locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => throw StateError('unknown location $locationId'),
    );
    final yaml = mihomoTunConfigYaml(location, routing: config.routing);
    final serverIp = location.proxy['server']?.toString() ?? '';
    final routing = config.routing;
    final routingDesc =
        routing == null ? 'none (full tunnel)' : '${routing.mode}, ${routing.rules.length} rule(s)';
    Log.i('NE connect: location=${location.id} (${location.label}) server=$serverIp routing=$routingDesc');
    try {
      await _control.invokeMethod<void>('start', {'config': yaml, 'server_ip': serverIp});
    } on PlatformException catch (e) {
      Log.e('NE start failed', e.message ?? e.code);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _control.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      Log.e('NE stop failed', e.message ?? e.code);
    }
  }

  @override
  Future<String?> engineVersion() async => 'mihomo (NetworkExtension)';

  VpnStatus _mapStatus(String? s) {
    switch (s) {
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
        return VpnStatus.connecting;
      case 'error':
        return VpnStatus.error;
      default:
        return VpnStatus.disconnected;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
