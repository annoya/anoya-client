import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'dns_servers.dart';
import 'mihomo_proxy.dart';
import 'subscription.dart';

const _plumbing = {'freedom', 'blackhole', 'dns', 'loopback'};

ParsedSubscription? parseXrayServers(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  final configs = switch (decoded) {
    List() => decoded,
    Map() => [decoded],
    _ => null,
  };
  if (configs == null || configs.isEmpty) return null;
  if (!configs.any((c) => c is Map && c['outbounds'] is List)) return null;

  final out = <Location>[];
  final unsupported = <String, int>{};
  var index = 0;
  for (final cfg in configs) {
    if (cfg is! Map) continue;
    final label = '${cfg['remarks'] ?? ''}'.trim();
    final description = _metaDescription(cfg['meta']);
    for (final ob in (cfg['outbounds'] as List? ?? const [])) {
      if (ob is! Map) continue;
      final protocol = '${ob['protocol'] ?? ''}'.toLowerCase();
      if (protocol.isEmpty || _plumbing.contains(protocol)) continue;
      final tag = '${ob['tag'] ?? ''}'.trim();
      try {
        final proxy = _proxyFor(protocol, ob);
        if (proxy == null) {
          unsupported.update(protocol, (n) => n + 1, ifAbsent: () => 1);
          continue;
        }
        final skip = _applyStream(proxy, protocol, ob['streamSettings']);
        if (skip != null) {
          unsupported.update(skip, (n) => n + 1, ifAbsent: () => 1);
          continue;
        }
        out.add(
          locationFor(
            'xray:$index:${proxy['server']}:${proxy['port']}',
            labelOr(
              label.isNotEmpty ? label : tag,
              '${proxy['server']}',
              proxy['port'] as int? ?? 0,
            ),
            proxy,
            description: description.isNotEmpty
                ? description
                : _metaDescription(ob['meta']),
          ),
        );
      } catch (e) {
        Log.e('xray json: unusable outbound', '$protocol -> $e');
      }
      index++;
    }
  }
  if (out.isEmpty && unsupported.isEmpty) return null;
  return ParsedSubscription(
    locations: out,
    unsupported: unsupported,
    dns: _dnsServers(configs),
    format: SubscriptionFormat.xray,
  );
}

List<String> _dnsServers(List configs) {
  final out = <String>[];
  for (final cfg in configs) {
    if (cfg is! Map) continue;
    final dns = cfg['dns'];
    if (dns is! Map) continue;
    for (final entry in (dns['servers'] as List? ?? const [])) {
      final address = switch (entry) {
        String() => entry,
        Map() => '${entry['address'] ?? ''}',
        _ => '',
      };
      var s = address.trim();
      final local = s.contains('+local://');
      if (local) s = s.replaceFirst('+local://', '://');
      final ns = mihomoNameserver(s, viaTunnel: !local);
      if (ns != null && !out.contains(ns)) out.add(ns);
    }
  }
  return out;
}

Map<String, dynamic>? _proxyFor(String protocol, Map ob) {
  final settings = ob['settings'];
  if (settings is! Map) return null;

  switch (protocol) {
    case 'vless':
    case 'vmess':
      final vnext = (settings['vnext'] as List? ?? const []).firstOrNull;
      if (vnext is! Map) return null;
      final user = (vnext['users'] as List? ?? const []).firstOrNull;
      if (user is! Map) return null;
      final proxy = <String, dynamic>{
        'type': protocol,
        'server': '${vnext['address'] ?? ''}',
        'port': _int(vnext['port']),
        'uuid': '${user['id'] ?? ''}',
        'udp': true,
      };
      if (protocol == 'vless') {
        final flow = '${user['flow'] ?? ''}';
        if (flow.isNotEmpty) proxy['flow'] = flow;
      } else {
        proxy['alterId'] = _int(user['alterId'] ?? user['alterid'] ?? 0);
        final scy = '${user['security'] ?? ''}';
        proxy['cipher'] = scy.isEmpty ? 'auto' : scy;
      }
      return proxy;

    case 'trojan':
    case 'shadowsocks':
      final server = (settings['servers'] as List? ?? const []).firstOrNull;
      if (server is! Map) return null;
      final proxy = <String, dynamic>{
        'type': protocol == 'trojan' ? 'trojan' : 'ss',
        'server': '${server['address'] ?? ''}',
        'port': _int(server['port']),
        'password': '${server['password'] ?? ''}',
        'udp': true,
      };
      if (protocol == 'shadowsocks') {
        proxy['cipher'] = '${server['method'] ?? ''}';
      }
      return proxy;

    default:
      return null;
  }
}

String? _applyStream(
  Map<String, dynamic> proxy,
  String protocol,
  Object? stream,
) {
  final ss = stream is Map ? stream : const {};
  final network = '${ss['network'] ?? 'tcp'}'.toLowerCase();
  final security = '${ss['security'] ?? 'none'}'.toLowerCase();
  final tls = security == 'tls' || security == 'reality' || security == 'xtls';

  if (proxy['type'] == 'trojan') {
    proxy['network'] = network;
  } else {
    proxy['network'] = network;
    proxy['tls'] = tls;
  }

  final tlsSettings = ss['tlsSettings'] is Map
      ? ss['tlsSettings'] as Map
      : const {};
  final reality = ss['realitySettings'] is Map
      ? ss['realitySettings'] as Map
      : const {};
  final sni = '${tlsSettings['serverName'] ?? reality['serverName'] ?? ''}';
  if (tls && sni.isNotEmpty) {
    proxy[proxy['type'] == 'trojan' ? 'sni' : 'servername'] = sni;
  }
  final fp = '${tlsSettings['fingerprint'] ?? reality['fingerprint'] ?? ''}';
  if (fp.isNotEmpty) proxy['client-fingerprint'] = fp;
  final alpn = (tlsSettings['alpn'] as List? ?? const [])
      .map((e) => '$e')
      .toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
  if (tlsSettings['allowInsecure'] == true) proxy['skip-cert-verify'] = true;
  if (security == 'reality') {
    final r = <String, dynamic>{};
    final pbk = '${reality['publicKey'] ?? ''}';
    if (pbk.isNotEmpty) r['public-key'] = pbk;
    final sid = '${reality['shortId'] ?? ''}';
    if (sid.isNotEmpty) r['short-id'] = sid;
    if (reality['mldsa65Verify'] != null || reality['pqv'] == true) {
      r['support-x25519mlkem768'] = true;
    }
    proxy['reality-opts'] = r;
  }

  final tcp = ss['tcpSettings'] is Map ? ss['tcpSettings'] as Map : const {};
  final header = tcp['header'] is Map ? tcp['header'] as Map : const {};
  final ws = ss['wsSettings'] is Map ? ss['wsSettings'] as Map : const {};
  final upgrade = ss['httpupgradeSettings'] is Map
      ? ss['httpupgradeSettings'] as Map
      : const {};
  final grpc = ss['grpcSettings'] is Map ? ss['grpcSettings'] as Map : const {};
  final http = ss['httpSettings'] is Map ? ss['httpSettings'] as Map : const {};
  final xhttp = ss['xhttpSettings'] is Map
      ? ss['xhttpSettings'] as Map
      : const {};

  final wsHost =
      '${(ws['headers'] is Map ? (ws['headers'] as Map)['Host'] : null) ?? ''}';
  final httpHost =
      (http['host'] as List? ?? const []).map((e) => '$e').firstOrNull ?? '';

  return applyTransport(proxy, network, {
    'path':
        '${ws['path'] ?? upgrade['path'] ?? http['path'] ?? xhttp['path'] ?? ''}',
    'host': wsHost.isNotEmpty
        ? wsHost
        : '${upgrade['host'] ?? (httpHost.isNotEmpty ? httpHost : xhttp['host'] ?? '')}',
    'serviceName': '${grpc['serviceName'] ?? ''}',
    'headerType': '${header['type'] ?? ''}',
    'mode': '${xhttp['mode'] ?? ''}',
    if (xhttp['extra'] != null) 'extra': jsonEncode(xhttp['extra']),
  }, protocol: protocol == 'shadowsocks' ? 'ss' : protocol);
}

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

String _metaDescription(Object? meta) =>
    meta is Map ? '${meta['serverDescription'] ?? ''}'.trim() : '';
