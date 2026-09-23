import 'dart:convert';

import '../norm_config.dart';
import 'base64_text.dart';
import 'mihomo_proxy.dart';

const kShareLinkSchemes = {
  'vless',
  'vmess',
  'trojan',
  'ss',
  'hysteria2',
  'hy2',
};

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

  final Location? location;

  final String? unsupported;

  final String? malformed;
}

Location? parseProxyUri(String raw) => parseShareLink(raw).location;

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
    // Only the reason, never the exception text: Uri.parse echoes the input, and
    // its userinfo is the credential.
    final why = e is FormatException ? e.message : e.runtimeType.toString();
    return ShareLink.malformed('$scheme:// $why');
  }
}

String _unwrapBase64Uri(String s, String scheme) {
  final prefix = '$scheme://';
  final (body, query, fragment) = _splitUriTail(s.substring(prefix.length));
  if (body.isEmpty || body.contains('@')) return s;
  final decoded = tryDecodeLooseBase64(body);
  if (decoded == null || !decoded.contains('@')) return s;
  final unwrapped = decoded.startsWith(prefix)
      ? decoded.substring(prefix.length)
      : decoded;
  final (inner, innerQuery, innerFragment) = _splitUriTail(unwrapped);
  final q = [innerQuery, query].where((p) => p.isNotEmpty).join('&');
  final f = fragment.isNotEmpty ? fragment : innerFragment;
  return '$prefix$inner${q.isEmpty ? '' : '?$q'}${f.isEmpty ? '' : '#$f'}';
}

(String, String, String) _splitUriTail(String s) {
  final hash = s.indexOf('#');
  final head = hash < 0 ? s : s.substring(0, hash);
  final fragment = hash < 0 ? '' : s.substring(hash + 1);
  final mark = head.indexOf('?');
  return mark < 0
      ? (head, '', fragment)
      : (head.substring(0, mark), head.substring(mark + 1), fragment);
}

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
    'uuid': _vlessUuid(u.userInfo),
    'network': network,
    'udp': true,
    'tls': tls,
  };
  final flow = q['flow'];
  if (flow != null && flow.isNotEmpty) proxy['flow'] = flow;
  final sni = q['sni'] ?? q['host'];
  if (tls && sni != null && sni.isNotEmpty) proxy['servername'] = sni;
  if (q['fp'] != null && q['fp']!.isNotEmpty) {
    proxy['client-fingerprint'] = q['fp'];
  }
  applyAlpn(proxy, q['alpn']);
  if (security == 'reality') {
    final r = <String, dynamic>{};
    if (q['pbk'] != null) r['public-key'] = q['pbk'];
    if (q['sid'] != null && q['sid']!.isNotEmpty) r['short-id'] = q['sid'];
    if (q['pqv'] == '1' || q['pqv'] == 'true') {
      r['support-x25519mlkem768'] = true;
    }
    proxy['reality-opts'] = r;
  }
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') {
    proxy['skip-cert-verify'] = true;
  }
  final skip = applyTransport(proxy, network, q, protocol: 'vless');
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(
    locationFor(
      s,
      labelOr(meta.name, u.host, u.port),
      proxy,
      description: meta.description,
    ),
  );
}

String _vlessUuid(String userInfo) {
  final decoded = Uri.decodeComponent(userInfo);
  final colon = decoded.lastIndexOf(':');
  return colon < 0 ? decoded : decoded.substring(colon + 1);
}

ShareLink _parseVmess(String s) {
  final json =
      jsonDecode(decodeLooseBase64(s.substring('vmess://'.length)))
          as Map<String, dynamic>;
  return _parseJsonPayload(s, json, 'vmess');
}

ShareLink _parseJsonPayload(
  String s,
  Map<String, dynamic> json,
  String protocol,
) {
  String str(String k) => json[k]?.toString() ?? '';
  final net = (str('net').isEmpty ? 'tcp' : str('net')).toLowerCase();
  final security = (str('tls').isEmpty ? str('security') : str('tls'))
      .toLowerCase();
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
  final skip = applyTransport(proxy, net, {
    'path': str('path'),
    'host': str('host'),
    'serviceName': str('path'),
    'headerType': str('type'),
  }, protocol: protocol);
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(str('ps'));
  return ShareLink.server(
    locationFor(
      s,
      labelOr(meta.name, str('add'), _int(json['port'])),
      proxy,
      description: meta.description,
    ),
  );
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
  if (q['fp'] != null && q['fp']!.isNotEmpty) {
    proxy['client-fingerprint'] = q['fp'];
  }
  applyAlpn(proxy, q['alpn']);
  if (q['allowInsecure'] == '1' || q['insecure'] == '1') {
    proxy['skip-cert-verify'] = true;
  }
  final skip = applyTransport(proxy, network, q, protocol: 'trojan');
  if (skip != null) return ShareLink.unsupported(skip);
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(
    locationFor(
      s,
      labelOr(meta.name, u.host, u.port),
      proxy,
      description: meta.description,
    ),
  );
}

ShareLink _parseShadowsocks(String s) {
  final hashIdx = s.indexOf('#');
  final frag = hashIdx >= 0
      ? Uri.decodeComponent(s.substring(hashIdx + 1))
      : '';
  var body = s.substring('ss://'.length, hashIdx >= 0 ? hashIdx : s.length);

  String method, password, host;
  int port;
  if (body.contains('@')) {
    final at = body.lastIndexOf('@');
    final userInfo = decodeLooseBase64(body.substring(0, at));
    final hostPort = body.substring(at + 1);
    method = userInfo.split(':').first;
    password = userInfo.substring(userInfo.indexOf(':') + 1);
    host = hostPort.substring(0, hostPort.lastIndexOf(':'));
    port = int.parse(
      hostPort
          .substring(hostPort.lastIndexOf(':') + 1)
          .split('/')
          .first
          .split('?')
          .first,
    );
  } else {
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
  final query = body.contains('?') ? body.substring(body.indexOf('?') + 1) : '';
  final plugin = Uri.splitQueryString(query)['plugin'] ?? '';
  if (plugin.isNotEmpty) {
    final skip = _applySsPlugin(proxy, plugin);
    if (skip != null) return ShareLink.unsupported(skip);
  }
  final meta = splitFragment(frag);
  return ShareLink.server(
    locationFor(
      s,
      labelOr(meta.name, host, port),
      proxy,
      description: meta.description,
    ),
  );
}

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
    case 'obfs-local':
    case 'simple-obfs':
    case 'obfs':
      final mode = opts['obfs'] ?? '';
      if (mode != 'http' && mode != 'tls') return 'ss+obfs ($mode)';
      proxy['plugin'] = 'obfs';
      proxy['plugin-opts'] = {
        'mode': mode,
        if ((opts['obfs-host'] ?? '').isNotEmpty) 'host': opts['obfs-host'],
      };
      return null;

    case 'v2ray-plugin':
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
      return 'ss+$name';
  }
}

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
  final alpn = (q['alpn'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
  if (q['insecure'] == '1' || q['allowInsecure'] == '1') {
    proxy['skip-cert-verify'] = true;
  }
  if ((q['obfs'] ?? '').isNotEmpty) {
    proxy['obfs'] = q['obfs'];
    final pw = q['obfs-password'] ?? q['obfs_password'];
    if (pw != null && pw.isNotEmpty) proxy['obfs-password'] = pw;
  }
  final ports = q['ports'] ?? q['mport'];
  if (ports != null && ports.isNotEmpty) proxy['ports'] = ports;
  if ((q['pinSHA256'] ?? '').isNotEmpty) proxy['fingerprint'] = q['pinSHA256'];
  final meta = splitFragment(safeDecode(u.fragment));
  return ShareLink.server(
    locationFor(
      s,
      labelOr(meta.name, u.host, u.port),
      proxy,
      description: meta.description,
    ),
  );
}

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
