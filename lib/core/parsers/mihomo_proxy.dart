import 'dart:convert';

import '../norm_config.dart';
import 'base64_text.dart';

void applyAlpn(Map<String, dynamic> proxy, String? raw) {
  final alpn = (raw ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
}

const kTransportsByProtocol = {
  'vless': {'', 'tcp', 'ws', 'httpupgrade', 'grpc', 'http', 'h2', 'xhttp'},
  'vmess': {'', 'tcp', 'ws', 'httpupgrade', 'grpc', 'http', 'h2'},
  'trojan': {'', 'tcp', 'ws', 'httpupgrade', 'grpc'},
};

String? applyTransport(
  Map<String, dynamic> proxy,
  String requested,
  Map<String, String> q, {
  required String protocol,
}) {
  final net = requested == 'raw' ? 'tcp' : requested;
  if (net != requested) proxy['network'] = net;
  final allowed = kTransportsByProtocol[protocol];
  if (allowed != null && !allowed.contains(net)) {
    return net.isEmpty ? 'tcp' : net;
  }

  final path = q['path'] ?? '';
  final host = q['host'] ?? '';

  switch (net) {
    case '':
    case 'tcp':
      if ((q['headerType'] ?? '') == 'http') {
        proxy['network'] = 'http';
        final opts = <String, dynamic>{};
        if (path.isNotEmpty) opts['path'] = [path];
        if (host.isNotEmpty) {
          opts['headers'] = {
            'Host': [host],
          };
        }
        proxy['http-opts'] = opts;
      }
      return null;

    case 'ws':
    case 'httpupgrade':
      final ws = <String, dynamic>{};
      if (path.isNotEmpty) ws['path'] = path;
      if (host.isNotEmpty) ws['headers'] = {'Host': host};
      if (net == 'httpupgrade') {
        // The engine has no httpupgrade network: it is websocket without the handshake.
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
      if (_xhttpHasDownloadSettings(q['extra'])) {
        return 'xhttp (split download)';
      }
      final opts = <String, dynamic>{};
      if (path.isNotEmpty) opts['path'] = path;
      if (host.isNotEmpty) opts['host'] = host;
      final mode = q['mode'] ?? '';
      if (mode.isNotEmpty) opts['mode'] = mode;
      proxy['xhttp-opts'] = opts;
      return null;

    default:
      return net;
  }
}

bool _xhttpHasDownloadSettings(String? extra) {
  if (extra == null || extra.isEmpty) return false;
  try {
    final j = jsonDecode(extra);
    return j is Map && j['downloadSettings'] != null;
  } catch (_) {
    return false;
  }
}

Location locationFor(
  String uri,
  String label,
  Map<String, dynamic> proxy, {
  String description = '',
}) {
  final server = (proxy['server'] as String?)?.trim() ?? '';
  final port = proxy['port'] as int? ?? 0;
  if (server.isEmpty) throw const FormatException('no server');
  if (port < 1 || port > 65535) {
    throw FormatException('port out of range: $port');
  }
  proxy['server'] = bareHost(server);
  return Location(
    id: 'link_${shortDigest(uri)}',
    label: label,
    proxy: proxy,
    description: description,
  );
}

String bareHost(String host) => host.startsWith('[') && host.endsWith(']')
    ? host.substring(1, host.length - 1)
    : host;

String labelOr(String frag, String host, int port) {
  final f = frag.trim();
  return f.isNotEmpty ? f : '$host:$port';
}

String safeDecode(String s) {
  try {
    return Uri.decodeComponent(s);
  } catch (_) {
    return s;
  }
}

({String name, String description}) splitFragment(String fragment) {
  final at = fragment.indexOf('?');
  if (at < 0) return (name: fragment, description: '');
  final query = fragment.substring(at + 1);
  final looksLikeParams = kFragmentParams.any((k) => query.startsWith('$k='));
  Map<String, String> params;
  try {
    params = Uri.splitQueryString(query);
  } catch (_) {
    params = const {};
  }
  if (!looksLikeParams && !params.keys.any(kFragmentParams.contains)) {
    return (name: fragment, description: '');
  }
  final raw = params['serverDescription'] ?? '';
  return (
    name: fragment.substring(0, at),
    description: raw.isEmpty ? '' : (tryDecodeLooseBase64(raw) ?? raw),
  );
}

const kFragmentParams = {'serverDescription', 'title'};
