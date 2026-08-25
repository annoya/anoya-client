import 'dart:convert';

import '../norm_config.dart';
import 'base64_text.dart';

/// The bits of "describe a server in mihomo's own words" that every source
/// format needs.
///
/// Three formats arrive — share links, Xray JSON, sing-box JSON — and they
/// describe the same handful of transports in three vocabularies. Only the
/// vocabulary differs: each parser reduces its own shape to the normalised bag
/// of strings below, and the mapping into mihomo keys happens once, here.
/// Duplicating it per format is how one of them quietly starts emitting a
/// transport the engine cannot dial.

/// ALPN is a list in the engine and comma-separated in a URI. Dropping it is
/// not harmless: a server that expects h3 or h2 refuses the handshake outright
/// when the client offers something else.
void applyAlpn(Map<String, dynamic> proxy, String? raw) {
  final alpn = (raw ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (alpn.isNotEmpty) proxy['alpn'] = alpn;
}

// --- helpers ---

/// Which transports each protocol can actually run, per the engine's own
/// adapters: vless and vmess carry the full set, trojan only ws and grpc.
/// Declared rather than discovered, because emitting a transport the engine
/// rejects turns a listed server into one that fails at connect time.
const kTransportsByProtocol = {
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
String? applyTransport(
  Map<String, dynamic> proxy,
  String net,
  Map<String, String> q, {
  required String protocol,
}) {
  final allowed = kTransportsByProtocol[protocol];
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
Location locationFor(String uri, String label, Map<String, dynamic> proxy,
    {String description = ''}) {
  final server = (proxy['server'] as String?)?.trim() ?? '';
  final port = proxy['port'] as int? ?? 0;
  if (server.isEmpty) throw const FormatException('no server');
  if (port < 1 || port > 65535) throw FormatException('port out of range: $port');
  proxy['server'] = bareHost(server);
  return Location(
    id: 'link_${shortDigest(uri)}',
    label: label,
    proxy: proxy,
    description: description,
  );
}

/// An IPv6 literal reaches us bracketed in the URI forms that carry host:port
/// as text (ss://). mihomo brackets it itself when dialing, so leaving them in
/// produces "[[::1]]:443" — strip them here, where every parser passes.
String bareHost(String host) => host.startsWith('[') && host.endsWith(']')
    ? host.substring(1, host.length - 1)
    : host;

String labelOr(String frag, String host, int port) {
  final f = frag.trim();
  return f.isNotEmpty ? f : '$host:$port';
}


/// URI fragments are percent-encoded UTF-8 (remarks often carry a flag emoji +
/// spaces). `Uri.fragment` returns the raw encoded form, so decode it here;
/// fall back to the raw string if it isn't valid percent-encoding.
String safeDecode(String s) {
  try {
    return Uri.decodeComponent(s);
  } catch (_) {
    return s;
  }
}

/// A share link's fragment, split into the name and what a provider hung off
/// it: `#Netherlands?serverDescription=<base64>`.
///
/// Only split on a `?` that is followed by parameters we know. A name is free
/// text — "Why not?" is a legal one — and cutting it at the first question mark
/// would rename servers for everyone to serve one convention.
({String name, String description}) splitFragment(String fragment) {
  final at = fragment.indexOf('?');
  if (at < 0) return (name: fragment, description: '');
  final query = fragment.substring(at + 1);
  // A query we cannot read is still recognisably one when it opens with a
  // parameter we know: the name is then what it always was, and only the
  // parameter is lost. Showing "Germany?serverDescription=%%%" as the server's
  // name would be a worse answer than showing "Germany".
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
    // base64 here, plain text in the JSON formats. Undecodable is not a reason
    // to lose the name that came with it.
    description: raw.isEmpty ? '' : (tryDecodeLooseBase64(raw) ?? raw),
  );
}

/// Parameters a provider may hang off a link's fragment. `title` is the name
/// itself, which is what the fragment already is; it is listed so a link
/// carrying only that is still recognised as carrying parameters.
const kFragmentParams = {'serverDescription', 'title'};
