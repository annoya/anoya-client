import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'dns_servers.dart';
import 'mihomo_proxy.dart';
import 'subscription.dart';

const _notServers = {'selector', 'urltest', 'direct', 'block', 'dns'};

const _types = {
  'vless': 'vless',
  'vmess': 'vmess',
  'trojan': 'trojan',
  'shadowsocks': 'ss',
  'hysteria2': 'hysteria2',
};

ParsedSubscription? parseSingboxServers(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map || decoded['outbounds'] is! List) return null;
  final list = decoded['outbounds'] as List;
  if (!list.any((o) => o is Map && o['type'] != null)) return null;

  final out = <Location>[];
  final unsupported = <String, int>{};
  var index = 0;
  for (final ob in list) {
    if (ob is! Map) continue;
    final kind = '${ob['type'] ?? ''}'.toLowerCase();
    if (kind.isEmpty || _notServers.contains(kind)) continue;
    final type = _types[kind];
    if (type == null) {
      unsupported.update(kind, (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    try {
      final proxy = _proxyFor(type, ob);
      final skip =
          _applyTls(proxy, ob['tls']) ?? _applyTransport(proxy, type, ob);
      if (skip != null) {
        unsupported.update(skip, (n) => n + 1, ifAbsent: () => 1);
        continue;
      }
      out.add(
        locationFor(
          'singbox:$index:${proxy['server']}:${proxy['port']}',
          labelOr(
            '${ob['tag'] ?? ''}'.trim(),
            '${proxy['server']}',
            proxy['port'] as int? ?? 0,
          ),
          proxy,
          description: ob['meta'] is Map
              ? '${(ob['meta'] as Map)['serverDescription'] ?? ''}'.trim()
              : '',
        ),
      );
    } catch (e) {
      Log.e('sing-box: unusable outbound', '$kind -> $e');
    }
    index++;
  }
  if (out.isEmpty && unsupported.isEmpty) return null;
  return ParsedSubscription(
    locations: out,
    unsupported: unsupported,
    dns: _dnsServers(decoded['dns'], list),
    format: SubscriptionFormat.singbox,
  );
}

List<String> _dnsServers(Object? node, List outbounds) {
  if (node is! Map) return const [];
  final servers = node['servers'];
  if (servers is! List) return const [];

  final onTheDevice = <String>{
    for (final ob in outbounds)
      if (ob is Map && (ob['type'] == 'direct' || ob['type'] == 'block'))
        '${ob['tag'] ?? ''}',
  };

  final out = <String>[];
  for (final entry in servers) {
    if (entry is! Map) continue;
    final detour = '${entry['detour'] ?? ''}'.trim();
    final viaTunnel = detour.isNotEmpty && !onTheDevice.contains(detour);
    final ns = mihomoNameserver(_address(entry), viaTunnel: viaTunnel);
    if (ns != null && !out.contains(ns)) out.add(ns);
  }
  return out;
}

String _address(Map entry) {
  final type = '${entry['type'] ?? ''}'.trim();
  if (type.isEmpty) return '${entry['address'] ?? ''}';
  final host = '${entry['server'] ?? ''}'.trim();
  if (host.isEmpty) return '$type://';
  final port = entry['server_port'];
  final path = '${entry['path'] ?? ''}';
  return '$type://$host${port == null ? '' : ':$port'}$path';
}

Map<String, dynamic> _proxyFor(String type, Map ob) {
  final proxy = <String, dynamic>{
    'type': type,
    'server': '${ob['server'] ?? ''}',
    'port': _int(ob['server_port']),
    'udp': true,
  };
  switch (type) {
    case 'vless':
      proxy['uuid'] = '${ob['uuid'] ?? ''}';
      final flow = '${ob['flow'] ?? ''}';
      if (flow.isNotEmpty) proxy['flow'] = flow;
    case 'vmess':
      proxy['uuid'] = '${ob['uuid'] ?? ''}';
      proxy['alterId'] = _int(ob['alter_id'] ?? 0);
      final scy = '${ob['security'] ?? ''}';
      proxy['cipher'] = scy.isEmpty ? 'auto' : scy;
    case 'trojan':
      proxy['password'] = '${ob['password'] ?? ''}';
    case 'ss':
      proxy['password'] = '${ob['password'] ?? ''}';
      proxy['cipher'] = '${ob['method'] ?? ''}';
    case 'hysteria2':
      proxy['password'] = '${ob['password'] ?? ''}';
      final obfs = ob['obfs'];
      if (obfs is Map) {
        proxy['obfs'] = '${obfs['type'] ?? ''}';
        proxy['obfs-password'] = '${obfs['password'] ?? ''}';
      }
  }
  return proxy;
}

String? _applyTls(Map<String, dynamic> proxy, Object? node) {
  final tls = node is Map ? node : const {};
  final enabled = tls['enabled'] == true;
  if (proxy['type'] != 'trojan' && proxy['type'] != 'hysteria2') {
    proxy['tls'] = enabled;
  }
  if (!enabled) return null;

  final sni = '${tls['server_name'] ?? ''}';
  if (sni.isNotEmpty) {
    proxy[proxy['type'] == 'trojan' || proxy['type'] == 'hysteria2'
            ? 'sni'
            : 'servername'] =
        sni;
  }
  final alpn = (tls['alpn'] as List? ?? const []).map((e) => '$e').toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
  if (tls['insecure'] == true) proxy['skip-cert-verify'] = true;
  final utls = tls['utls'];
  if (utls is Map && utls['enabled'] == true) {
    final fp = '${utls['fingerprint'] ?? ''}';
    if (fp.isNotEmpty) proxy['client-fingerprint'] = fp;
  }
  final reality = tls['reality'];
  if (reality is Map && reality['enabled'] == true) {
    final r = <String, dynamic>{};
    final pbk = '${reality['public_key'] ?? ''}';
    if (pbk.isNotEmpty) r['public-key'] = pbk;
    final sid = '${reality['short_id'] ?? ''}';
    if (sid.isNotEmpty) r['short-id'] = sid;
    proxy['reality-opts'] = r;
  }
  return null;
}

String? _applyTransport(Map<String, dynamic> proxy, String type, Map ob) {
  if (type == 'hysteria2') return null;
  final t = ob['transport'] is Map ? ob['transport'] as Map : const {};
  final kind = '${t['type'] ?? 'tcp'}'.toLowerCase();
  final headers = t['headers'] is Map ? t['headers'] as Map : const {};
  final host = '${headers['Host'] ?? headers['host'] ?? t['host'] ?? ''}';

  // sing-box "http" is HTTP/2; mihomo's `http` is obfuscated TCP.
  final network = kind == 'http' ? 'h2' : kind;
  // Set before the shared mapping, which only overrides where names differ.
  proxy['network'] = network;

  return applyTransport(proxy, network, {
    'path': '${t['path'] ?? ''}',
    'host': host,
    'serviceName': '${t['service_name'] ?? ''}',
  }, protocol: type);
}

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
