import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';

/// Share links: `vless://`, `vmess://`, `trojan://`, `ss://`.
///
/// One link describes one server and nothing else — no account, no policy, no
/// origin to re-ask (ADR-005). The result's `proxy` map is already in **mihomo
/// proxy format** (mihomo field names like `ws-opts`, `reality-opts`,
/// `servername`), so the config renderer emits it almost verbatim.

/// Parse one share-link URI. Returns null if the scheme is unknown or malformed.
Location? parseProxyUri(String raw) {
  final s = raw.trim();
  try {
    final scheme = s.split('://').first.toLowerCase();
    switch (scheme) {
      case 'vless':
        return _parseVless(s);
      case 'vmess':
        return _parseVmess(s);
      case 'trojan':
        return _parseTrojan(s);
      case 'ss':
        return _parseShadowsocks(s);
      default:
        return null;
    }
  } catch (e) {
    // Scheme only: the link's userinfo IS the credential (uuid/password), and
    // this log line ends up in the support archive.
    Log.e('proxy uri parse failed', '${s.split('://').first}:// -> $e');
    return null;
  }
}


// --- per-protocol ---

Location _parseVless(String s) {
  final u = Uri.parse(s);
  final q = u.queryParameters;
  final security = (q['security'] ?? 'none').toLowerCase();
  final tls = security == 'tls' || security == 'reality' || security == 'xtls';
  final network = (q['type'] ?? 'tcp').toLowerCase();
  final proxy = <String, dynamic>{
    'type': 'vless',
    'server': u.host,
    'port': u.port,
    'uuid': Uri.decodeComponent(u.userInfo),
    'network': network,
    'udp': true,
    'tls': tls,
  };
  final flow = q['flow'];
  if (flow != null && flow.isNotEmpty) proxy['flow'] = flow;
  final sni = q['sni'] ?? q['host'];
  if (tls && sni != null && sni.isNotEmpty) proxy['servername'] = sni;
  if (q['fp'] != null && q['fp']!.isNotEmpty) proxy['client-fingerprint'] = q['fp'];
  if (security == 'reality') {
    final r = <String, dynamic>{};
    if (q['pbk'] != null) r['public-key'] = q['pbk'];
    if (q['sid'] != null && q['sid']!.isNotEmpty) r['short-id'] = q['sid'];
    proxy['reality-opts'] = r;
  }
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') proxy['skip-cert-verify'] = true;
  _applyTransport(proxy, network, q['path'], q['host'], q['serviceName']);
  return _loc(s, _label(_safeDecode(u.fragment), u.host, u.port), proxy);
}

Location _parseVmess(String s) {
  final json = jsonDecode(decodeLooseBase64(s.substring('vmess://'.length))) as Map<String, dynamic>;
  String str(String k) => json[k]?.toString() ?? '';
  final net = (str('net').isEmpty ? 'tcp' : str('net')).toLowerCase();
  final tls = str('tls') == 'tls';
  final proxy = <String, dynamic>{
    'type': 'vmess',
    'server': str('add'),
    'port': _int(json['port']),
    'uuid': str('id'),
    'alterId': _int(json['aid']),
    'cipher': str('scy').isEmpty ? 'auto' : str('scy'),
    'network': net,
    'udp': true,
    'tls': tls,
  };
  final sni = str('sni').isNotEmpty ? str('sni') : str('host');
  if (tls && sni.isNotEmpty) proxy['servername'] = sni;
  _applyTransport(proxy, net, str('path'), str('host'), str('path'));
  return _loc(s, _label(str('ps'), str('add'), _int(json['port'])), proxy);
}

Location _parseTrojan(String s) {
  final u = Uri.parse(s);
  final q = u.queryParameters;
  final network = (q['type'] ?? 'tcp').toLowerCase();
  final proxy = <String, dynamic>{
    'type': 'trojan',
    'server': u.host,
    'port': u.port,
    'password': Uri.decodeComponent(u.userInfo),
    'network': network,
    'udp': true,
  };
  final sni = q['sni'] ?? q['peer'];
  if (sni != null && sni.isNotEmpty) proxy['sni'] = sni;
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') proxy['skip-cert-verify'] = true;
  _applyTransport(proxy, network, q['path'], q['host'], q['serviceName']);
  return _loc(s, _label(_safeDecode(u.fragment), u.host, u.port), proxy);
}

Location _parseShadowsocks(String s) {
  // SIP002: ss://base64(method:password)@host:port#name
  // legacy:  ss://base64(method:password@host:port)#name
  final hashIdx = s.indexOf('#');
  final frag = hashIdx >= 0 ? Uri.decodeComponent(s.substring(hashIdx + 1)) : '';
  var body = s.substring('ss://'.length, hashIdx >= 0 ? hashIdx : s.length);

  String method, password, host;
  int port;
  if (body.contains('@')) {
    // SIP002
    final at = body.lastIndexOf('@');
    final userInfo = decodeLooseBase64(body.substring(0, at));
    final hostPort = body.substring(at + 1);
    method = userInfo.split(':').first;
    password = userInfo.substring(userInfo.indexOf(':') + 1);
    host = hostPort.substring(0, hostPort.lastIndexOf(':'));
    port = int.parse(hostPort.substring(hostPort.lastIndexOf(':') + 1).split('/').first.split('?').first);
  } else {
    // legacy: whole thing is base64
    final dec = decodeLooseBase64(body);
    final at = dec.lastIndexOf('@');
    final creds = dec.substring(0, at);
    final hostPort = dec.substring(at + 1);
    method = creds.split(':').first;
    password = creds.substring(creds.indexOf(':') + 1);
    host = hostPort.substring(0, hostPort.lastIndexOf(':'));
    port = int.parse(hostPort.substring(hostPort.lastIndexOf(':') + 1));
  }
  final proxy = <String, dynamic>{
    'type': 'ss',
    'server': host,
    'port': port,
    'cipher': method,
    'password': password,
    'udp': true,
  };
  return _loc(s, _label(frag, host, port), proxy);
}


// --- helpers ---

void _applyTransport(Map<String, dynamic> proxy, String net, String? path, String? host, String? serviceName) {
  switch (net) {
    case 'ws':
      final ws = <String, dynamic>{};
      if (path != null && path.isNotEmpty) ws['path'] = path;
      if (host != null && host.isNotEmpty) ws['headers'] = {'Host': host};
      if (ws.isNotEmpty) proxy['ws-opts'] = ws;
      break;
    case 'grpc':
      if (serviceName != null && serviceName.isNotEmpty) {
        proxy['grpc-opts'] = {'grpc-service-name': serviceName};
      }
      break;
  }
}

/// Builds the Location, rejecting a proxy the engine could not dial anyway.
/// Every parser funnels through here, so "server and port are sane" holds for
/// anything that reaches the renderer — a port of 0 (what a malformed vmess
/// `port` decodes to) would otherwise ship as a config the engine accepts and
/// silently cannot use.
Location _loc(String uri, String label, Map<String, dynamic> proxy) {
  final server = (proxy['server'] as String?)?.trim() ?? '';
  final port = proxy['port'] as int? ?? 0;
  if (server.isEmpty) throw const FormatException('no server');
  if (port < 1 || port > 65535) throw FormatException('port out of range: $port');
  proxy['server'] = _bareHost(server);
  return Location(id: 'link_${shortDigest(uri)}', label: label, proxy: proxy);
}

/// An IPv6 literal reaches us bracketed in the URI forms that carry host:port
/// as text (ss://). mihomo brackets it itself when dialing, so leaving them in
/// produces "[[::1]]:443" — strip them here, where every parser passes.
String _bareHost(String host) => host.startsWith('[') && host.endsWith(']')
    ? host.substring(1, host.length - 1)
    : host;

String _label(String frag, String host, int port) {
  final f = frag.trim();
  return f.isNotEmpty ? f : '$host:$port';
}


/// URI fragments are percent-encoded UTF-8 (remarks often carry a flag emoji +
/// spaces). `Uri.fragment` returns the raw encoded form, so decode it here;
/// fall back to the raw string if it isn't valid percent-encoding.
String _safeDecode(String s) {
  try {
    return Uri.decodeComponent(s);
  } catch (_) {
    return s;
  }
}



int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

