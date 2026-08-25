import 'dart:convert';

import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'mihomo_proxy.dart';

/// Share links: `vless://`, `vmess://`, `trojan://`, `ss://`.
///
/// One link describes one server and nothing else — no account, no policy, no
/// origin to re-ask (ADR-005). The result's `proxy` map is already in **mihomo
/// proxy format** (mihomo field names like `ws-opts`, `reality-opts`,
/// `servername`), so the config renderer emits it almost verbatim.

/// The schemes this file understands. Shared with the paste detector so a new
/// protocol is added in one place rather than two that drift.
const kShareLinkSchemes = {'vless', 'vmess', 'trojan', 'ss', 'hysteria2', 'hy2'};

/// What one share link turned out to be: a server we can run, or the name of
/// what stopped us.
///
/// The distinction matters for the count the user sees. A `vless://` link with
/// `type=kcp` is not "an unsupported protocol" — vless is supported — so the
/// reason has to be the transport, which is also the thing they can look up.
class ShareLink {
  const ShareLink.server(Location this.location) : unsupported = null;
  const ShareLink.unsupported(String this.unsupported) : location = null;
  const ShareLink.junk() : location = null, unsupported = null;

  /// Null when this link is not something we can run.
  final Location? location;

  /// What we could not run — a scheme (`tuic`) or a transport (`kcp`). Null
  /// when the text was not a server at all.
  final String? unsupported;
}

/// Parse one share-link URI. Null when the scheme is unknown or malformed; use
/// [parseShareLink] when the reason matters.
Location? parseProxyUri(String raw) => parseShareLink(raw).location;

/// Parse one share-link URI, keeping the reason a link was not usable.
ShareLink parseShareLink(String raw) {
  final s = raw.trim();
  final scheme = s.contains('://') ? s.split('://').first.toLowerCase() : '';
  try {
    return switch (scheme) {
      'vless' => _parseVless(s),
      'vmess' => _parseVmess(s),
      'trojan' => _parseTrojan(s),
      'ss' => _parseShadowsocks(s),
      'hysteria2' || 'hy2' => _parseHysteria2(s),
      '' => const ShareLink.junk(),
      _ => ShareLink.unsupported(scheme),
    };
  } catch (e) {
    // Scheme only: the link's userinfo IS the credential (uuid/password), and
    // this log line ends up in the support archive.
    Log.e('proxy uri parse failed', '$scheme:// -> $e');
    // A link of a scheme we know that will not parse is malformed, not
    // unsupported — saying "vless unsupported" would be a lie.
    return const ShareLink.junk();
  }
}


// --- per-protocol ---

ShareLink _parseVless(String s) {
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
  applyAlpn(proxy, q['alpn']);
  if (security == 'reality') {
    final r = <String, dynamic>{};
    if (q['pbk'] != null) r['public-key'] = q['pbk'];
    if (q['sid'] != null && q['sid']!.isNotEmpty) r['short-id'] = q['sid'];
    // Post-quantum key exchange: the server advertises it, and a client that
    // ignores the flag negotiates the classical curve instead.
    if (q['pqv'] == '1' || q['pqv'] == 'true') r['support-x25519mlkem768'] = true;
    proxy['reality-opts'] = r;
  }
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') proxy['skip-cert-verify'] = true;
  final skip = applyTransport(proxy, network, q, protocol: 'vless');
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(locationFor(
      s, labelOr(meta.name, u.host, u.port), proxy,
      description: meta.description));
}

ShareLink _parseVmess(String s) {
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
  applyAlpn(proxy, str('alpn'));
  // A vmess payload names the same things a URI query does, under its own keys.
  final skip = applyTransport(proxy, net, {
    'path': str('path'),
    'host': str('host'),
    'serviceName': str('path'), // grpc service name lives in `path` here
    'headerType': str('type'),
  }, protocol: 'vmess');
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(str('ps'));
  return ShareLink.server(locationFor(
      s, labelOr(meta.name, str('add'), _int(json['port'])), proxy,
      description: meta.description));
}

ShareLink _parseTrojan(String s) {
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
  if (q['fp'] != null && q['fp']!.isNotEmpty) proxy['client-fingerprint'] = q['fp'];
  applyAlpn(proxy, q['alpn']);
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') proxy['skip-cert-verify'] = true;
  final skip = applyTransport(proxy, network, q, protocol: 'trojan');
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(locationFor(
      s, labelOr(meta.name, u.host, u.port), proxy,
      description: meta.description));
}

ShareLink _parseShadowsocks(String s) {
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
  // SIP003 plugin, if any. It is not decoration: a server behind obfuscation
  // refuses a plain connection, so a dropped plugin is a listed server that
  // always fails — which is why an unknown one is reported instead.
  final query = body.contains('?') ? body.substring(body.indexOf('?') + 1) : '';
  final plugin = Uri.splitQueryString(query)['plugin'] ?? '';
  if (plugin.isNotEmpty) {
    final skip = _applySsPlugin(proxy, plugin);
    if (skip != null) return ShareLink.unsupported(skip);
  }
  final meta = splitFragment(frag);
  return ShareLink.server(locationFor(s, labelOr(meta.name, host, port), proxy,
      description: meta.description));
}

/// Translates a SIP003 `plugin=` into mihomo's `plugin` / `plugin-opts`.
///
/// The wire format is `name;k=v;flag`, and the two plugins the engine has
/// adapters for spell their options differently from the URI (`obfs-local`'s
/// `obfs=http` is mihomo's `mode: http`). Returns null on success, otherwise
/// the name to count as unsupported.
String? _applySsPlugin(Map<String, dynamic> proxy, String spec) {
  final parts = spec.split(';');
  final name = parts.first.trim();
  final opts = <String, String>{};
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    final i = part.indexOf('=');
    if (i < 0) {
      opts[part.trim()] = 'true';
    } else {
      opts[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
  }

  switch (name) {
    // simple-obfs, under the three names it ships as.
    case 'obfs-local':
    case 'simple-obfs':
    case 'obfs':
      final mode = opts['obfs'] ?? '';
      // The engine accepts these two and errors on anything else, so a third
      // value is refused here rather than at dial time.
      if (mode != 'http' && mode != 'tls') return 'ss+obfs ($mode)';
      proxy['plugin'] = 'obfs';
      proxy['plugin-opts'] = {
        'mode': mode,
        if ((opts['obfs-host'] ?? '').isNotEmpty) 'host': opts['obfs-host'],
      };
      return null;

    case 'v2ray-plugin':
      // websocket is the only mode the engine implements.
      final mode = opts['mode'] ?? 'websocket';
      if (mode != 'websocket') return 'ss+v2ray-plugin ($mode)';
      proxy['plugin'] = 'v2ray-plugin';
      proxy['plugin-opts'] = {
        'mode': 'websocket',
        if ((opts['host'] ?? '').isNotEmpty) 'host': opts['host'],
        if ((opts['path'] ?? '').isNotEmpty) 'path': opts['path'],
        if (opts.containsKey('tls')) 'tls': true,
      };
      return null;

    default:
      // shadow-tls, kcptun, restls and friends: mihomo has adapters for some,
      // but each needs its own option mapping, and guessing produces a server
      // that fails at connect.
      return 'ss+$name';
  }
}


/// hysteria2://password@host:port/?sni=…&alpn=h3&insecure=0#name
///
/// QUIC-based, so there is no transport to choose — the `type=` and `path=`
/// parameters the other schemes carry have no meaning here. `hy2://` is the
/// short alias panels also emit.
ShareLink _parseHysteria2(String s) {
  final u = Uri.parse(s);
  final q = u.queryParameters;
  final proxy = <String, dynamic>{
    'type': 'hysteria2',
    'server': u.host,
    'port': u.port,
    'password': Uri.decodeComponent(u.userInfo),
    'udp': true,
  };
  final sni = q['sni'] ?? q['peer'];
  if (sni != null && sni.isNotEmpty) proxy['sni'] = sni;
  // A list in mihomo, comma-separated in the URI.
  final alpn = (q['alpn'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
  if (q['insecure'] == '1' || q['allowInsecure'] == '1') proxy['skip-cert-verify'] = true;
  if ((q['obfs'] ?? '').isNotEmpty) {
    proxy['obfs'] = q['obfs'];
    final pw = q['obfs-password'] ?? q['obfs_password'];
    if (pw != null && pw.isNotEmpty) proxy['obfs-password'] = pw;
  }
  // Port hopping: a range the client rotates through. Two spellings in the
  // wild, one field in mihomo.
  final ports = q['ports'] ?? q['mport'];
  if (ports != null && ports.isNotEmpty) proxy['ports'] = ports;
  if ((q['pinSHA256'] ?? '').isNotEmpty) proxy['fingerprint'] = q['pinSHA256'];
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(locationFor(
      s, labelOr(meta.name, u.host, u.port), proxy,
      description: meta.description));
}

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

