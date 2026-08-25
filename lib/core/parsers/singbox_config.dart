import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'mihomo_proxy.dart';
import 'subscription.dart';

/// sing-box JSON as a server list — the fourth template family the panels
/// serve, and the one we used to read as nothing at all.
///
/// sing-box describes a server flatter than Xray does: address and credentials
/// at the top level of the outbound, TLS in one `tls` object, transport in one
/// `transport` object. That makes it the easiest of the three to read and the
/// easiest to get subtly wrong, because a missing `tls.enabled` is a working
/// config that fails at the handshake.

/// Outbound types that are not servers: selectors and the built-in sinks. A
/// panel's sing-box body always carries a `selector` listing every server, and
/// counting it as an unsupported protocol would invent a server that is not
/// there.
const _notServers = {'selector', 'urltest', 'direct', 'block', 'dns'};

/// mihomo's name for each sing-box protocol we can run.
const _types = {
  'vless': 'vless',
  'vmess': 'vmess',
  'trojan': 'trojan',
  'shadowsocks': 'ss',
  'hysteria2': 'hysteria2',
};

/// Reads the servers out of a sing-box body. Null when this is not one.
ParsedSubscription? parseSingboxServers(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map || decoded['outbounds'] is! List) return null;
  // Both this and an Xray config have `outbounds`; a sing-box one names each
  // entry with `type`, an Xray one with `protocol`.
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
      // wireguard, tuic, ssh, anytls…
      unsupported.update(kind, (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    try {
      final proxy = _proxyFor(type, ob);
      final skip = _applyTls(proxy, ob['tls']) ?? _applyTransport(proxy, type, ob);
      if (skip != null) {
        unsupported.update(skip, (n) => n + 1, ifAbsent: () => 1);
        continue;
      }
      out.add(locationFor(
        'singbox:$index:${proxy['server']}:${proxy['port']}',
        labelOr('${ob['tag'] ?? ''}'.trim(), '${proxy['server']}',
            proxy['port'] as int? ?? 0),
        proxy,
        description: ob['meta'] is Map
            ? '${(ob['meta'] as Map)['serverDescription'] ?? ''}'.trim()
            : '',
      ));
    } catch (e) {
      Log.e('sing-box: unusable outbound', '$kind -> $e');
    }
    index++;
  }
  if (out.isEmpty && unsupported.isEmpty) return null;
  return ParsedSubscription(
    locations: out,
    unsupported: unsupported,
    format: SubscriptionFormat.singbox,
  );
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

/// sing-box keeps TLS in one object; mihomo spreads it across the proxy. The
/// flag matters most: `tls` absent or disabled means a plaintext dial, and
/// assuming otherwise turns a working server into a failing one.
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
        : 'servername'] = sni;
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
  // QUIC protocols have no transport to choose, and sing-box does not give them
  // one.
  if (type == 'hysteria2') return null;
  final t = ob['transport'] is Map ? ob['transport'] as Map : const {};
  // No transport object at all is plain TCP, which is also what sing-box means
  // by omitting it.
  final kind = '${t['type'] ?? 'tcp'}'.toLowerCase();
  final headers = t['headers'] is Map ? t['headers'] as Map : const {};
  final host = '${headers['Host'] ?? headers['host'] ?? t['host'] ?? ''}';

  // sing-box calls HTTP/2 "http"; mihomo's `http` is the obfuscated-TCP network
  // and `h2` is HTTP/2, so the name has to be translated rather than passed
  // through.
  final network = kind == 'http' ? 'h2' : kind;
  // Set before the shared mapping runs, exactly as the link parsers do: that
  // helper only overrides the network where the engine's name differs
  // (httpupgrade is a websocket, tcp with an HTTP header is `http`).
  proxy['network'] = network;

  return applyTransport(
    proxy,
    network,
    {
      'path': '${t['path'] ?? ''}',
      'host': host,
      'serviceName': '${t['service_name'] ?? ''}',
    },
    protocol: type,
  );
}

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
