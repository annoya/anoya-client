import 'dart:convert';

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
  const ShareLink.server(Location this.location)
      : unsupported = null,
        malformed = null;
  const ShareLink.unsupported(String this.unsupported)
      : location = null,
        malformed = null;
  const ShareLink.malformed(String this.malformed)
      : location = null,
        unsupported = null;
  const ShareLink.junk()
      : location = null,
        unsupported = null,
        malformed = null;

  /// Null when this link is not something we can run.
  final Location? location;

  /// What we could not run — a scheme (`tuic`) or a transport (`kcp`). Null
  /// when the text was not a server at all.
  final String? unsupported;

  /// A link of a scheme we know that would not parse, and why — scheme and
  /// reason only, never the link itself, because the userinfo is the
  /// credential. Reported by the caller, which knows how many there were and
  /// where they came from; one line per link said neither.
  final String? malformed;
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
    // A link of a scheme we know that will not parse is malformed, not
    // unsupported — saying "vless unsupported" would be a lie.
    //
    // Only the reason travels, never the exception's own text: Uri.parse
    // prints the offending string under its message, and the userinfo in it
    // is the credential (AGENTS.md invariant 11).
    final why = e is FormatException ? e.message : e.runtimeType.toString();
    return ShareLink.malformed('$scheme:// $why');
  }
}


// --- per-protocol ---

/// A `vless://` or `trojan://` link whose payload is base64 rather than a URI.
///
/// Neither protocol has a standard base64 form, but panels and older clients
/// emit two anyway: base64 of the URI body (`uuid@host:port?…#name`), and for
/// vless the vmess-style base64 JSON. Both are recognised by what a URI body
/// cannot lack — `@` — and what base64 cannot contain: `@`, `?` and `#`.
///
/// Returns the link in URI form (the JSON form is handed to [_parseJsonPayload]
/// by the caller), or the link unchanged when it is already a URI.
String _unwrapBase64Uri(String s, String scheme) {
  final prefix = '$scheme://';
  final hash = s.indexOf('#');
  final body = s.substring(prefix.length, hash < 0 ? s.length : hash);
  if (body.contains('@') || body.contains('?') || body.isEmpty) return s;
  final decoded = tryDecodeLooseBase64(body);
  if (decoded == null || !decoded.contains('@')) return s;
  // The name may sit outside the base64 or inside it; outside wins when both.
  final fragment = hash < 0 ? '' : s.substring(hash);
  final inner = decoded.startsWith(prefix) ? decoded.substring(prefix.length) : decoded;
  return fragment.isNotEmpty && inner.contains('#')
      ? '$prefix${inner.substring(0, inner.indexOf('#'))}$fragment'
      : '$prefix$inner$fragment';
}

/// The vmess-style JSON object behind a base64 payload, or null when the payload
/// is not that.
Map<String, dynamic>? _base64Json(String s, String scheme) {
  final body = s.substring('$scheme://'.length).split('#').first;
  if (body.contains('@') || body.contains('?') || body.isEmpty) return null;
  final decoded = tryDecodeLooseBase64(body);
  if (decoded == null || !decoded.trimLeft().startsWith('{')) return null;
  final json = jsonDecode(decoded);
  return json is Map<String, dynamic> ? json : null;
}

ShareLink _parseVless(String raw) {
  final json = _base64Json(raw, 'vless');
  if (json != null) return _parseJsonPayload(raw, json, 'vless');
  final s = _unwrapBase64Uri(raw, 'vless');
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
  return _parseJsonPayload(s, json, 'vmess');
}

/// The base64-JSON payload: vmess's native form, and the one some panels emit
/// for vless under the same field names (`add`, `port`, `id`, `net`, `tls`,
/// `sni`, `host`, `path`, `ps`), plus vless's own `flow`, `fp`, `pbk`, `sid`.
ShareLink _parseJsonPayload(String s, Map<String, dynamic> json, String protocol) {
  String str(String k) => json[k]?.toString() ?? '';
  final net = (str('net').isEmpty ? 'tcp' : str('net')).toLowerCase();
  // `tls` carries the security name in this form; vmess only ever says "tls",
  // vless payloads also say "reality" (some under `security` instead).
  final security = (str('tls').isEmpty ? str('security') : str('tls')).toLowerCase();
  final tls = security == 'tls' || security == 'reality' || security == 'xtls';
  final proxy = <String, dynamic>{
    'type': protocol,
    'server': str('add'),
    'port': _int(json['port']),
    'uuid': str('id'),
    if (protocol == 'vmess') 'alterId': _int(json['aid']),
    if (protocol == 'vmess') 'cipher': str('scy').isEmpty ? 'auto' : str('scy'),
    'network': net,
    'udp': true,
    'tls': tls,
  };
  if (protocol == 'vless') {
    if (str('flow').isNotEmpty) proxy['flow'] = str('flow');
    if (str('fp').isNotEmpty) proxy['client-fingerprint'] = str('fp');
    if (security == 'reality') {
      proxy['reality-opts'] = {
        'public-key': str('pbk'),
        if (str('sid').isNotEmpty) 'short-id': str('sid'),
      };
    }
  }
  final sni = str('sni').isNotEmpty ? str('sni') : str('host');
  if (tls && sni.isNotEmpty) proxy['servername'] = sni;
  applyAlpn(proxy, str('alpn'));
  // The payload names the same things a URI query does, under its own keys.
  final skip = applyTransport(proxy, net, {
    'path': str('path'),
    'host': str('host'),
    'serviceName': str('path'), // grpc service name lives in `path` here
    'headerType': str('type'),
  }, protocol: protocol);
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(str('ps'));
  return ShareLink.server(locationFor(
      s, labelOr(meta.name, str('add'), _int(json['port'])), proxy,
      description: meta.description));
}

ShareLink _parseTrojan(String raw) {
  final s = _unwrapBase64Uri(raw, 'trojan');
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

