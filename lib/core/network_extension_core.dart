import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'app_version.dart';
import 'control_transport.dart';
import 'dns_plan.dart';
import 'log.dart';
import 'mihomo_tun_config.dart';
import 'norm_config.dart';
import 'on_demand.dart';
import 'rule_list_store.dart';
import 'vpn_core.dart';

/// NetworkExtensionCore drives the real tunnel, which always runs in another
/// process: the NEPacketTunnelProvider extension on macOS and iOS, the
/// VpnService in `:tunnel` on Android, the `AnnoyaTunnel` service on Windows.
/// The mihomo engine lives over there; this class only sends the rendered
/// config and start/stop commands and reflects the status that comes back.
/// Screens and state see only [VpnCore], which is what the tests replace with
/// a fake.
///
/// The [ControlTransport] is the one platform difference: channels the runner
/// registers, or the named pipe to the service. Everything said over it is the
/// same on every platform.
///
/// Note: the connect/disconnect path deliberately does NOT read the shared log
/// container — doing so from the host triggers a macOS "access data from other
/// apps" prompt. Logs are viewed on demand in the Logs screen instead.
class NetworkExtensionCore implements VpnCore {
  NetworkExtensionCore({ControlTransport? transport}) {
    if (transport != null) _transport = transport;
    // distinct(): NEVPNStatusDidChange can fire repeatedly for one transition
    // (and several NE statuses map to the same VpnStatus), which would churn
    // the UI on every flap.
    _statusStream = _transport.statusEvents
        .map(_mapStatus)
        .distinct()
        .asBroadcastStream();
    // Lives as long as the app: the core is a process-lifetime provider.
    _statusStream.listen((s) => _status = s);
  }

  /// One transport per process, shared with the static lookups below (geo
  /// directory, device info, group member) that run before or beside the
  /// core. The core's constructor installs the platform's; until then, and in
  /// tests, it is the channels — which throw MissingPluginException where there
  /// is no platform side, and every caller already reads that as "unavailable".
  static ControlTransport _transport = ChannelTransport();
  static ControlTransport get _control => _transport;

  late final Stream<VpnStatus> _statusStream;
  NormConfig? _config;
  VpnStatus _status = VpnStatus.disconnected;

  @override
  VpnStatus get status => _status;

  @override
  Stream<VpnStatus> statusStream() => _statusStream;

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
      await _control.invoke<void>('start', {
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
    await _control.invoke<void>('reload', {
      ...rendered,
      'log_enabled': Log.enabled,
    });
  }

  @override
  Future<void> disconnect() async {
    try {
      await _control.invoke<void>('stop');
    } on PlatformException catch (e) {
      Log.e('NE stop failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE stop failed', 'no platform side');
    }
  }

  @override
  Future<bool> applyOnDemand(
    OnDemandPrefs prefs, {
    NormConfig? config,
    String? locationId,
  }) async {
    final rendered = await _render(config, locationId);
    try {
      final armed = await _control.invoke<bool>('set_on_demand', {
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
      await _control.invoke<void>('sync_config', {
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
      await _control.invoke<void>('remove_profile');
      Log.i('system VPN profile removed');
    } on PlatformException catch (e) {
      Log.e('NE remove_profile failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE remove_profile failed', 'no platform side');
    }
  }

  /// Renders the config for one selection — a server, or a group whose member
  /// the engine picks. Null when there is nothing to render.
  ///
  /// The proxy server is deliberately NOT singled out here: the engine binds
  /// its own dials to the physical interface, so nothing has to be routed
  /// around the tunnel — which also means the server's hostname is never
  /// resolved outside it.
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

    // A place whose settings have not been issued yet (ADR-009). There is
    // nothing to render and nothing has gone wrong: the config is fetched when
    // the user connects, and syncing before that would spend a device slot on
    // a server they may never pick.
    if (location.isPlaceholder) return null;
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
            collectLogs: Log.enabled,
            autoDetectInterface: !Platform.isAndroid,
            // The Windows service has no host-opened device to hand the engine;
            // it creates the adapter itself, named after the app so the user
            // recognises it in the network list.
            device: Platform.isWindows ? kAppName : null),
      };
    } catch (e) {
      Log.e('config render failed', '$e');
      return null;
    }
  }

  /// Asks the engine — inside the extension, or in the tunnel process on
  /// Android — to fetch one page through the outbound the tunnel routes to.
  ///
  /// A platform failure is returned as an answer, not thrown: "the tunnel is
  /// not running" and "the server did not reply" are both results the user
  /// needs to read, and only one of them is about the server.
  @override
  Future<String> urlTest(String url, Duration timeout) async {
    try {
      final res = await _control.invoke<String>('url_test', {
        'url': url,
        'timeout_ms': timeout.inMilliseconds,
      });
      return res ?? 'err:the engine did not answer';
    } on PlatformException catch (e) {
      Log.e('NE url_test failed', e.message ?? e.code);
      return 'err:${e.message ?? e.code}';
    } on MissingPluginException {
      return 'err:this build cannot test the connection';
    }
  }

  /// What the engine has carried through the outbound so far.
  ///
  /// Best-effort by design — every failure answers "nothing", which sends the
  /// caller to the active probe rather than to an error.
  @override
  Future<String> proxyBytes() async {
    try {
      return await _control.invoke<String>('proxy_bytes') ?? '0:0';
    } on PlatformException catch (e) {
      Log.e('NE proxy_bytes failed', e.message ?? e.code);
      return '0:0';
    } on MissingPluginException {
      return '0:0';
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
      final epoch = await _control.invoke<double>('connected_since');
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
      return await _control.invoke<String>('disconnect_error') ?? '';
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
          .invoke<String>('group_member', {'group': group});
      return res ?? '';
    } on PlatformException catch (e) {
      Log.e('NE group_member failed', e.message ?? e.code);
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  /// What the platform says this device is: os, version, model. Null when
  /// there is no platform side (unsupported host, or tests).
  static Future<Map<String, String>?> deviceInfo() async {
    try {
      // Windows has no runner of its own to ask; what the Dart runtime knows
      // is what the panel gets.
      if (Platform.isWindows) {
        return {'os': 'Windows', 'version': Platform.operatingSystemVersion, 'model': ''};
      }
      final info = await _control.invoke<Map<dynamic, dynamic>>('device_info');
      if (info == null) return null;
      return info.map((k, v) => MapEntry('$k', '$v'));
    } on PlatformException catch (e) {
      Log.e('NE device_info failed', e.message ?? e.code);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// App Group container shared with the tunnel extension — the engine's home
  /// dir. GeoIP/GeoSite databases are downloaded here so mihomo (whose home is
  /// set to the same path) can read them. Null when the platform side has no
  /// group container (then geo rules are unavailable).
  static Future<String?> sharedDir() async {
    try {
      return await _control.invoke<String>('shared_dir');
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
}
