import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'dns_plan.dart';
import 'log.dart';
import 'mihomo_tun_config.dart';
import 'norm_config.dart';
import 'on_demand.dart';
import 'rule_list_store.dart';
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
    final rendered = await _render(config, locationId);
    if (rendered == null) throw StateError('unknown location $locationId');
    final yaml = rendered['config']!;
    final routing = config.routing;
    final routingDesc =
        routing == null ? 'none (full tunnel)' : '${routing.mode}, ${routing.rules.length} rule(s)';
    Log.i('NE connect: selection=$locationId routing=$routingDesc');
    try {
      await _control.invokeMethod<void>('start', {
        'config': yaml,
        'log_enabled': Log.enabled,
      });
    } on PlatformException catch (e) {
      Log.e('NE start failed', e.message ?? e.code);
      rethrow;
    }
  }

  @override
  Future<void> reload(NormConfig config, String locationId) async {
    final rendered = await _render(config, locationId);
    if (rendered == null) throw StateError('unknown location $locationId');
    Log.i('NE hot reload: location=$locationId');
    await _control.invokeMethod<void>('reload', {
      ...rendered,
      'log_enabled': Log.enabled,
    });
  }

  @override
  Future<void> disconnect() async {
    try {
      await _control.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      Log.e('NE stop failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE stop failed', 'no platform side');
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
    final rendered = await _render(config, locationId);
    try {
      final armed = await _control.invokeMethod<bool>('set_on_demand', {
        'enabled': prefs.armed,
        'rules': prefs.rules.map((r) => r.toChannel()).toList(),
        'disconnect_on_sleep': prefs.disconnectOnSleep,
        'log_enabled': Log.enabled,
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
    final rendered = await _render(config, locationId);
    if (rendered == null) return;
    try {
      await _control.invokeMethod<void>('sync_config', {
        ...rendered,
        'log_enabled': Log.enabled,
      });
    } on PlatformException catch (e) {
      // Best-effort: the profile may not exist yet, or the user may have
      // revoked it. The next connect writes the config anyway.
      Log.e('NE sync_config failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE sync_config failed', 'no platform side');
    }
  }

  @override
  Future<void> removeSystemProfile() async {
    try {
      await _control.invokeMethod<void>('remove_profile');
      Log.i('system VPN profile removed');
    } on PlatformException catch (e) {
      Log.e('NE remove_profile failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE remove_profile failed', 'no platform side');
    }
  }

  /// Renders the YAML the extension will run. Null when there is nothing to
  /// render. The proxy server is deliberately NOT singled out here: the engine
  /// binds its own dials to the physical interface, so nothing has to be routed
  /// around the tunnel — which also means the server's hostname is never
  /// resolved outside it.
  /// Renders the config for one selection — a server, or a group whose member
  /// the engine picks.
  ///
  /// gvisor on both macOS and iOS: it is fully userspace (no socket binds), the
  /// only stack that works inside the iOS NE sandbox (the `system` stack fails
  /// there trying to bind the fake-ip gateway). Log.enabled is the "collect
  /// logs" switch; the level rendered here is what an on-demand start (no app
  /// involved) will use.
  Future<Map<String, String>?> _render(NormConfig? config, String? locationId) async {
    if (config == null || locationId == null) return null;

    ProxyGroup? group;
    var members = const <Location>[];
    Location? location;
    if (ProxyGroup.isGroupId(locationId)) {
      for (final g in config.groups) {
        if (g.id == locationId) group = g;
      }
      if (group == null) return null;
      final byId = {for (final l in config.locations) l.id: l};
      members = [for (final id in group.members) if (byId[id] != null) byId[id]!];
      // A group whose members all disappeared from the subscription would
      // render an empty `proxies:` list, which the engine rejects — and it
      // would reject it while applying, i.e. with the tunnel already down.
      if (members.isEmpty) return null;
      location = members.first;
    } else {
      for (final l in config.locations) {
        if (l.id == locationId) location = l;
      }
      if (location == null) return null;
    }

    try {
      final listPaths =
          await RuleListStore.availablePaths(config.routing?.lists ?? const []);
      return {
        'config': mihomoTunConfigYaml(location,
            group: group,
            members: members,
            routing: config.routing,
            dns: config.dns,
            defaultDns: config.defaultDns.isEmpty
                ? kFallbackNameserver
                : config.defaultDns,
            listPaths: listPaths,
            stack: 'gvisor',
            collectLogs: Log.enabled,
            autoDetectInterface: !Platform.isAndroid),
      };
    } catch (e) {
      Log.e('config render failed', '$e');
      return null;
    }
  }

  /// When the system established the current session.
  ///
  /// `NEVPNConnection.connectedDate` — the moment the connection came up,
  /// whoever brought it up. The app used to stamp its own time on first sight,
  /// which is right only when the app was watching: a tunnel started from the
  /// system's VPN switch, or by an on-demand rule, had been running for hours
  /// and the clock read seconds.
  @override
  Future<DateTime?> connectedSince() async {
    try {
      final epoch = await _control.invokeMethod<double>('connected_since');
      if (epoch == null || epoch <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch((epoch * 1000).round());
    } on PlatformException catch (e) {
      Log.e('NE connected_since failed', e.message ?? e.code);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Why the tunnel last stopped, as the system recorded it.
  ///
  /// Empty when there is nothing to tell. A failure inside the extension never
  /// reaches the call that started it — the app only sees the status fall back
  /// — so this is how a refused config stops looking like a connect that gave
  /// up on its own.
  @override
  Future<String> lastDisconnectError() async {
    try {
      return await _control.invokeMethod<String>('disconnect_error') ?? '';
    } on PlatformException catch (e) {
      Log.e('NE disconnect_error failed', e.message ?? e.code);
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  /// Which member of the rendered proxy group the engine currently uses.
  ///
  /// Empty when nothing is running, when the config has no group, or before the
  /// first health check has landed — all of which mean the same thing to the
  /// caller: not known yet, so say "auto" and nothing more.
  static Future<String> groupMember(String group) async {
    try {
      final res = await _control
          .invokeMethod<String>('group_member', {'group': group});
      return res ?? '';
    } on PlatformException catch (e) {
      Log.e('NE group_member failed', e.message ?? e.code);
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  /// App Group container shared with the tunnel extension — the engine's home
  /// dir. GeoIP/GeoSite databases are downloaded here so mihomo (whose home is
  /// What the platform says this device is: os, version, model. Null when
  /// there is no platform side (unsupported host, or tests).
  static Future<Map<String, String>?> deviceInfo() async {
    try {
      final info = await _control.invokeMethod<Map<dynamic, dynamic>>('device_info');
      if (info == null) return null;
      return info.map((k, v) => MapEntry('$k', '$v'));
    } on PlatformException catch (e) {
      Log.e('NE device_info failed', e.message ?? e.code);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// set to the same path) can read them. Null when the platform side has no
  /// group container (then geo rules are unavailable).
  static Future<String?> sharedDir() async {
    try {
      return await _control.invokeMethod<String>('shared_dir');
    } on PlatformException catch (e) {
      Log.e('NE shared_dir failed', e.message ?? e.code);
      return null;
    } on MissingPluginException {
      // No platform side at all (unsupported host, or tests): geo rules are
      // simply unavailable, which the caller already handles.
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
