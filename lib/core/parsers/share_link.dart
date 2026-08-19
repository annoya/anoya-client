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
  _applyAlpn(proxy, q['alpn']);
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
  final skip = _applyTransport(proxy, network, q, protocol: 'vless');
  if (skip != null) return ShareLink.unsupported(skip);
  return ShareLink.server(_loc(s, _label(_safeDecode(u.fragment), u.host, u.port), proxy));
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
  _applyAlpn(proxy, str('alpn'));
  // A vmess payload names the same things a URI query does, under its own keys.
  final skip = _applyTransport(proxy, net, {
    'path': str('path'),
    'host': str('host'),
    'serviceName': str('path'), // grpc service name lives in `path` here
    'headerType': str('type'),
  }, protocol: 'vmess');
  if (skip != null) return ShareLink.unsupported(skip);
  return ShareLink.server(_loc(s, _label(str('ps'), str('add'), _int(json['port'])), proxy));
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
  _applyAlpn(proxy, q['alpn']);
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') proxy['skip-cert-verify'] = true;
  final skip = _applyTransport(proxy, network, q, protocol: 'trojan');
  if (skip != null) return ShareLink.unsupported(skip);
  return ShareLink.server(_loc(s, _label(_safeDecode(u.fragment), u.host, u.port), proxy));
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
  return ShareLink.server(_loc(s, _label(frag, host, port), proxy));
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
  return ShareLink.server(_loc(s, _label(_safeDecode(u.fragment), u.host, u.port), proxy));
}

/// ALPN is a list in the engine and comma-separated in a URI. Dropping it is
/// not harmless: a server that expects h3 or h2 refuses the handshake outright
/// when the client offers something else.
void _applyAlpn(Map<String, dynamic> proxy, String? raw) {
  final alpn = (raw ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
}

// --- helpers ---

/// Which transports each protocol can actually run, per the engine's own
/// adapters: vless and vmess carry the full set, trojan only ws and grpc.
/// Declared rather than discovered, because emitting a transport the engine
/// rejects turns a listed server into one that fails at connect time.
const _transportsByProtocol = {
  'vless': {'', 'tcp', 'ws', 'httpupgrade', 'grpc', 'http', 'h2', 'xhttp'},
  'vmess': {'', 'tcp', 'ws', 'httpupgrade', 'grpc', 'http', 'h2'},
  'trojan': {'', 'tcp', 'ws', 'httpupgrade', 'grpc'},
};

/// Fills in the transport section, or names what stopped it.
///
/// A share link's `type=` is the transport, and the engine expresses several of
/// them differently from the URI: `headerType=http` on tcp is the engine's
/// `http` network, and `httpupgrade` is a websocket with a flag. Getting that
/// mapping wrong is invisible until a connection fails, so the ones we cannot
/// express are reported as unsupported instead of silently degraded to plain
/// tcp — which is what a dropped transport used to become.
///
/// Returns null on success, otherwise the transport's name for the count the
/// user is shown.
String? _applyTransport(
  Map<String, dynamic> proxy,
  String net,
  Map<String, String> q, {
  required String protocol,
}) {
  final allowed = _transportsByProtocol[protocol];
  if (allowed != null && !allowed.contains(net)) return net.isEmpty ? 'tcp' : net;

  final path = q['path'] ?? '';
  final host = q['host'] ?? '';

  switch (net) {
    case '':
    case 'tcp':
      // Plain tcp needs nothing. With an HTTP header it is a different network
      // in the engine, and the obfuscation is what the server expects.
      if ((q['headerType'] ?? '') == 'http') {
        proxy['network'] = 'http';
        final opts = <String, dynamic>{};
        if (path.isNotEmpty) opts['path'] = [path]; // a list in the engine
        if (host.isNotEmpty) opts['headers'] = {'Host': [host]};
        proxy['http-opts'] = opts;
      }
      return null;

    case 'ws':
    case 'httpupgrade':
      final ws = <String, dynamic>{};
      if (path.isNotEmpty) ws['path'] = path;
      if (host.isNotEmpty) ws['headers'] = {'Host': host};
      if (net == 'httpupgrade') {
        // The engine has no separate httpupgrade network: it is a websocket
        // that skips the WebSocket handshake, which is exactly what this flag
        // does. (Remnawave's own mihomo output maps it the same way.)
        proxy['network'] = 'ws';
        ws['v2ray-http-upgrade'] = true;
        ws['v2ray-http-upgrade-fast-open'] = true;
      }
      if (ws.isNotEmpty) proxy['ws-opts'] = ws;
      return null;

    case 'grpc':
      final name = q['serviceName'] ?? '';
      if (name.isNotEmpty) proxy['grpc-opts'] = {'grpc-service-name': name};
      return null;

    case 'h2':
      final opts = <String, dynamic>{};
      if (path.isNotEmpty) opts['path'] = path;
      if (host.isNotEmpty) opts['host'] = [host];
      if (opts.isNotEmpty) proxy['h2-opts'] = opts;
      return null;

    case 'xhttp':
      // `extra` carries tuning (padding, xmux) plus, sometimes, a second
      // channel for downloads. Tuning we can leave at the engine's defaults;
      // a split download channel changes the topology, and dialing one channel
      // when the server expects two fails in a way no message would explain.
      if (_xhttpHasDownloadSettings(q['extra'])) return 'xhttp (split download)';
      final opts = <String, dynamic>{};
      if (path.isNotEmpty) opts['path'] = path;
      if (host.isNotEmpty) opts['host'] = host;
      final mode = q['mode'] ?? '';
      if (mode.isNotEmpty) opts['mode'] = mode;
      proxy['xhttp-opts'] = opts;
      return null;

    default:
      // kcp, quic and whatever comes next: the engine has no adapter, and the
      // panels that emit them filter them out for engine-based clients anyway.
      return net;
  }
}

bool _xhttpHasDownloadSettings(String? extra) {
  if (extra == null || extra.isEmpty) return false;
  try {
    final j = jsonDecode(extra);
    return j is Map && j['downloadSettings'] != null;
  } catch (_) {
    // Unreadable extra is not a reason to refuse the server; the fields it
    // carries are optional to begin with.
    return false;
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

