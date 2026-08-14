import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'log.dart';
import 'norm_config.dart';

/// Parses share links (vless://, vmess://, trojan://, ss://) and subscription
/// bodies (base64 list of links, or Clash/mihomo YAML) into [Location]s.
///
/// Each Location's `proxy` map is already in **mihomo proxy format** (mihomo
/// field names like `ws-opts`, `reality-opts`, `servername`), so the config
/// renderer emits it almost verbatim. Only "vless/vmess/trojan/ss" are handled.

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

/// Parse a subscription body: Clash/mihomo YAML (has `proxies:`) or a (usually
/// base64-encoded) newline/whitespace-separated list of share links.
List<Location> parseSubscription(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return [];

  // Clash/mihomo YAML?
  final clash = _tryParseClash(trimmed);
  if (clash != null) return clash;

  // Otherwise a link list — possibly base64-wrapped.
  var text = trimmed;
  if (!text.contains('://')) {
    final decoded = _tryB64(text);
    if (decoded != null && decoded.contains('://')) text = decoded;
  }
  final out = <Location>[];
  for (final line in text.split(RegExp(r'[\r\n\s]+'))) {
    if (line.isEmpty) continue;
    final loc = parseProxyUri(line);
    if (loc != null) out.add(loc);
  }
  return out;
}

/// Resolvers a Clash/mihomo-YAML subscription ships in `dns.nameserver`;
/// empty for link lists and anything unparseable. Mined separately from the
/// proxies because our tunnel config keeps its own dns block (fake-ip range
/// and mode are app constants) and adopts only the resolvers.
List<String> subscriptionDns(String body) {
  final trimmed = body.trim();
  if (!RegExp(r'(^|\n)\s*dns\s*:').hasMatch(trimmed)) return const [];
  try {
    final doc = loadYaml(trimmed);
    if (doc is! Map) return const [];
    final dns = doc['dns'];
    if (dns is! Map) return const [];
    final ns = dns['nameserver'];
    if (ns is! List) return const [];
    return [
      for (final e in ns)
        if (e != null && '$e'.trim().isNotEmpty) '$e'.trim(),
    ];
  } catch (e) {
    Log.e('subscription dns parse failed', '$e');
    return const [];
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
  final json = jsonDecode(_b64(s.substring('vmess://'.length))) as Map<String, dynamic>;
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
    final userInfo = _b64(body.substring(0, at));
    final hostPort = body.substring(at + 1);
    method = userInfo.split(':').first;
    password = userInfo.substring(userInfo.indexOf(':') + 1);
    host = hostPort.substring(0, hostPort.lastIndexOf(':'));
    port = int.parse(hostPort.substring(hostPort.lastIndexOf(':') + 1).split('/').first.split('?').first);
  } else {
    // legacy: whole thing is base64
    final dec = _b64(body);
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

// --- Clash YAML ---

List<Location>? _tryParseClash(String body) {
  if (!RegExp(r'(^|\n)\s*proxies\s*:').hasMatch(body)) return null;
  try {
    final doc = loadYaml(body);
    if (doc is! Map || doc['proxies'] is! List) return null;
    final out = <Location>[];
    var i = 0;
    for (final p in (doc['proxies'] as List)) {
      final m = _deepConvert(p);
      if (m is! Map<String, dynamic> || m['type'] == null || m['server'] == null) continue;
      final name = m['name']?.toString() ?? '${m['server']}:${m['port']}';
      out.add(Location(id: 'sub_${i++}_${_hash(name)}', label: name, proxy: m));
    }
    return out.isEmpty ? null : out;
  } catch (e) {
    Log.e('clash yaml parse failed', '$e');
    return null;
  }
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

Location _loc(String uri, String label, Map<String, dynamic> proxy) =>
    Location(id: 'link_${_hash(uri)}', label: label, proxy: proxy);

String _label(String frag, String host, int port) {
  final f = frag.trim();
  return f.isNotEmpty ? f : '$host:$port';
}

/// What a pasted string on the add screen turned out to be — drives the live
/// detection chip and enables Continue.
enum InputKind {
  /// A single share link (vless:// etc.) → a link profile.
  link,

  /// An http(s) URL, fetched as a subscription on Continue.
  subscriptionUrl,

  /// Raw subscription content (base64 list / Clash YAML), parsed locally.
  subscriptionText,
}

class DetectedInput {
  const DetectedInput(this.kind, this.label, {this.serverCount = 0});

  final InputKind kind;
  final String label; // what to show in the chip
  final int serverCount; // known for local text, 0 for URLs (fetched later)
}

/// Classifies pasted text without any network I/O. Null → nothing usable yet.
DetectedInput? detectInput(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final scheme = t.contains('://') ? t.split('://').first.toLowerCase() : '';
  // A share link is a single token; multi-line vless:// lists are a
  // subscription and fall through to the parser below.
  final singleToken = !t.contains(RegExp(r'\s'));
  if (singleToken && const {'vless', 'vmess', 'trojan', 'ss'}.contains(scheme)) {
    final loc = parseProxyUri(t);
    return loc == null
        ? null
        : DetectedInput(InputKind.link, '${loc.proxyType.toUpperCase()} server · ${loc.label}',
            serverCount: 1);
  }
  if (scheme == 'http' || scheme == 'https') {
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return null;
    return DetectedInput(InputKind.subscriptionUrl, 'Subscription URL · ${u.host}');
  }
  final locs = parseSubscription(t);
  if (locs.isEmpty) return null;
  return locs.length == 1
      ? DetectedInput(InputKind.link, 'Server · ${locs.first.label}', serverCount: 1)
      : DetectedInput(InputKind.subscriptionText, 'Subscription · ${locs.length} servers',
          serverCount: locs.length);
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

String _hash(String s) => sha1.convert(utf8.encode(s)).toString().substring(0, 10);

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

/// Base64 decode tolerant of url-safe alphabet and missing padding.
String _b64(String s) {
  var t = s.trim().replaceAll('-', '+').replaceAll('_', '/');
  final pad = t.length % 4;
  if (pad != 0) t += '=' * (4 - pad);
  return utf8.decode(base64.decode(t));
}

String? _tryB64(String s) {
  try {
    return _b64(s);
  } catch (_) {
    return null;
  }
}

/// Recursively converts YamlMap/YamlList into plain `Map<String,dynamic>`/List.
dynamic _deepConvert(dynamic node) {
  if (node is YamlMap || node is Map) {
    return <String, dynamic>{
      for (final e in (node as Map).entries) e.key.toString(): _deepConvert(e.value),
    };
  }
  if (node is YamlList || node is List) {
    return [for (final e in (node as List)) _deepConvert(e)];
  }
  return node;
}
