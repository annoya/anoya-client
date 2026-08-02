import 'dart:async';

import 'package:flutter/services.dart';

import 'log.dart';
import 'mihomo_tun_config.dart';
import 'norm_config.dart';
import 'on_demand.dart';
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
    // distinct(): NEVPNStatusDidChange can fire repeatedly for one transition
    // (and several NE statuses map to the same VpnStatus), which would churn
    // the UI on every flap.
    _statusStream = _statusEvents
        .receiveBroadcastStream()
        .map((e) => _mapStatus(e as String?))
        .distinct()
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
    // gvisor on both macOS and iOS: it's fully userspace (no socket binds), the
    // only stack that works inside the iOS NE sandbox. (The `system` stack
    // fails there trying to bind the fake-ip gateway.)
    final yaml = mihomoTunConfigYaml(location, routing: config.routing, stack: 'gvisor');
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

  @override
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async {
    final rendered = _render(config, locationId);
    try {
      final armed = await _control.invokeMethod<bool>('set_on_demand', {
        'enabled': prefs.armed,
        'rules': prefs.rules.map((r) => r.toChannel()).toList(),
        'disconnect_on_sleep': prefs.disconnectOnSleep,
        if (rendered != null) ...rendered,
      });
      Log.i('on-demand ${armed == true ? 'armed' : 'not armed'} (${prefs.rules.length} rule(s))');
      return armed ?? false;
    } on PlatformException catch (e) {
      Log.e('NE set_on_demand failed', e.message ?? e.code);
      rethrow;
    }
  }

  @override
  Future<void> syncConfig(NormConfig config, String locationId) async {
    final rendered = _render(config, locationId);
    if (rendered == null) return;
    try {
      await _control.invokeMethod<void>('sync_config', rendered);
    } on PlatformException catch (e) {
      // Best-effort: the profile may not exist yet, or the user may have
      // revoked it. The next connect writes the config anyway.
      Log.e('NE sync_config failed', e.message ?? e.code);
    }
  }

  @override
  Future<void> removeSystemProfile() async {
    try {
      await _control.invokeMethod<void>('remove_profile');
      Log.i('system VPN profile removed');
    } on PlatformException catch (e) {
      Log.e('NE remove_profile failed', e.message ?? e.code);
    }
  }

  /// Renders the YAML the extension will run plus the server IP to exclude
  /// from the tunnel. Null when there is nothing to render.
  Map<String, String>? _render(NormConfig? config, String? locationId) {
    if (config == null || locationId == null) return null;
    Location? location;
    for (final l in config.locations) {
      if (l.id == locationId) location = l;
    }
    if (location == null) return null;
    try {
      return {
        'config': mihomoTunConfigYaml(location, routing: config.routing, stack: 'gvisor'),
        'server_ip': location.proxy['server']?.toString() ?? '',
      };
    } catch (e) {
      Log.e('config render failed', '$e');
      return null;
    }
  }

  /// App Group container shared with the tunnel extension — the engine's home
  /// dir. GeoIP/GeoSite databases are downloaded here so mihomo (whose home is
  /// set to the same path) can read them. Null when the platform side has no
  /// group container (then geo rules are unavailable).
  static Future<String?> sharedDir() async {
    try {
      return await _control.invokeMethod<String>('shared_dir');
    } on PlatformException catch (e) {
      Log.e('NE shared_dir failed', e.message ?? e.code);
      return null;
    }
  }

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
