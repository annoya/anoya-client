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
import 'platform_support.dart';
import 'rule_list_store.dart';
import 'vpn_core.dart';

class NetworkExtensionCore implements VpnCore {
  NetworkExtensionCore({ControlTransport? transport}) {
    if (transport != null) _transport = transport;
    // distinct(): NEVPNStatusDidChange can fire repeatedly for one transition.
    _statusStream = _transport.statusEvents
        .map(_mapStatus)
        .distinct()
        .asBroadcastStream();
    _statusStream.listen((s) => _status = s);
  }

  static ControlTransport _transport = ChannelTransport();
  static ControlTransport get _control => _transport;

  static ControlTransport get control => _transport;

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
    final routingDesc = routing == null
        ? 'none (full tunnel)'
        : '${routing.mode}, ${routing.rules.length} rule(s)';
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
        ...?rendered,
      });
      Log.i(
        'on-demand ${armed == true ? 'armed' : 'not armed'} (${prefs.rules.length} rule(s))',
      );
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

  Future<Map<String, String>?> _render(
    NormConfig? config,
    String? locationId,
  ) async {
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
      members = [
        for (final id in group.members)
          if (byId[id] != null) byId[id]!,
      ];
      if (members.isEmpty) return null;
      location = members.first;
    } else {
      for (final l in config.locations) {
        if (l.id == locationId) location = l;
      }
      if (location == null) return null;
    }

    if (location.isPlaceholder) return null;
    try {
      final listPaths = await RuleListStore.availablePaths(
        config.routing?.lists ?? const [],
      );
      return {
        'config': mihomoTunConfigYaml(
          location,
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
          processNamesNeedExe: Platform.isWindows,
          device: Platform.isWindows || Platform.isLinux ? kAppName : null,
          dnsDecoy: Platform.isAndroid ? kAndroidDnsDecoy : null,
          mtu: Platform.isAndroid ? kAndroidTunMtu : kTunMtu,
        ),
      };
    } catch (e) {
      Log.e('config render failed', '$e');
      return null;
    }
  }

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

  @override
  Future<void> setAutoConnect(bool enabled) async {
    if (!supportsBootAutoConnect) return;
    try {
      await _control.invoke<void>('set_auto_connect', {'enabled': enabled});
    } on PlatformException catch (e) {
      Log.e('NE set_auto_connect failed', e.message ?? e.code);
    } on MissingPluginException {
      Log.e('NE set_auto_connect failed', 'no platform side');
    }
  }

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

  static Future<String> groupMember(String group) async {
    try {
      final res = await _control.invoke<String>('group_member', {
        'group': group,
      });
      return res ?? '';
    } on PlatformException catch (e) {
      Log.e('NE group_member failed', e.message ?? e.code);
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  static Future<Map<String, String>?> deviceInfo() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        return {
          'os': Platform.isWindows ? 'Windows' : 'Linux',
          'version': Platform.operatingSystemVersion,
          'model': '',
        };
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

  static Future<String?> sharedDir() async {
    try {
      return await _control.invoke<String>('shared_dir');
    } on PlatformException catch (e) {
      Log.e('NE shared_dir failed', e.message ?? e.code);
      return null;
    } on MissingPluginException {
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
