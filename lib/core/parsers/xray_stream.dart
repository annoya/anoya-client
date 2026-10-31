import 'mihomo_proxy.dart';

Map _map(Object? v) => v is Map ? v : const {};

String _security(Map stream) => '${stream['security'] ?? 'none'}'.toLowerCase();

bool xrayTls(Map stream) {
  final security = _security(stream);
  return security == 'tls' || security == 'reality' || security == 'xtls';
}

void applyXraySecurity(
  Map<String, dynamic> proxy,
  Map stream, {
  String sniKey = 'servername',
}) {
  final tlsSettings = _map(stream['tlsSettings']);
  final reality = _map(stream['realitySettings']);
  applyTls(
    proxy,
    tls: xrayTls(stream),
    sniKey: sniKey,
    sni: '${tlsSettings['serverName'] ?? reality['serverName'] ?? ''}',
    fingerprint:
        '${tlsSettings['fingerprint'] ?? reality['fingerprint'] ?? ''}',
    alpn: (tlsSettings['alpn'] as List? ?? const []).map((e) => '$e').toList(),
    insecure: tlsSettings['allowInsecure'] == true,
    reality: _security(stream) == 'reality'
        ? (
            publicKey: '${reality['publicKey'] ?? ''}',
            shortId: '${reality['shortId'] ?? ''}',
            pqv: reality['mldsa65Verify'] != null || reality['pqv'] == true,
          )
        : null,
  );
}

const _xhttpKeys = {
  'headers': 'headers',
  'noGRPCHeader': 'no-grpc-header',
  'xPaddingBytes': 'x-padding-bytes',
  'xPaddingObfsMode': 'x-padding-obfs-mode',
  'xPaddingKey': 'x-padding-key',
  'xPaddingHeader': 'x-padding-header',
  'xPaddingPlacement': 'x-padding-placement',
  'xPaddingMethod': 'x-padding-method',
  'uplinkHTTPMethod': 'uplink-http-method',
  'sessionPlacement': 'session-placement',
  'sessionKey': 'session-key',
  'sessionTable': 'session-table',
  'sessionLength': 'session-length',
  'sessionIDPlacement': 'session-placement',
  'sessionIDKey': 'session-key',
  'sessionIDTable': 'session-table',
  'sessionIDLength': 'session-length',
  'seqPlacement': 'seq-placement',
  'seqKey': 'seq-key',
  'uplinkDataPlacement': 'uplink-data-placement',
  'uplinkDataKey': 'uplink-data-key',
  'uplinkChunkSize': 'uplink-chunk-size',
  'scMaxEachPostBytes': 'sc-max-each-post-bytes',
  'scMinPostsIntervalMs': 'sc-min-posts-interval-ms',
};

const _xmuxKeys = {
  'maxConcurrency': 'max-concurrency',
  'maxConnections': 'max-connections',
  'cMaxReuseTimes': 'c-max-reuse-times',
  'hMaxRequestTimes': 'h-max-request-times',
  'hMaxReusableSecs': 'h-max-reusable-secs',
  'hKeepAlivePeriod': 'h-keep-alive-period',
};

Map<String, dynamic> _renamed(Map from, Map<String, String> keys) => {
  for (final MapEntry(:key, :value) in keys.entries) value: ?_value(from[key]),
};

Object? _value(Object? v) => switch (v) {
  null || false || '' => null,
  Map() when v.isEmpty => null,
  Map() => {for (final e in v.entries) '${e.key}': '${e.value}'},
  _ => v,
};

Map<String, dynamic> xhttpOptions(Map settings) {
  final out = _renamed(settings, _xhttpKeys);
  final reuse = _renamed(_map(settings['xmux']), _xmuxKeys);
  if (reuse.isNotEmpty) out['reuse-settings'] = reuse;
  if (settings['downloadSettings'] case final Map ds) {
    out['download-settings'] = _download(ds);
  }
  return out;
}

Map<String, dynamic> _download(Map stream) {
  final out = <String, dynamic>{'tls': xrayTls(stream)};
  final server = '${stream['address'] ?? ''}';
  if (server.isNotEmpty) out['server'] = server;
  final port = int.tryParse('${stream['port'] ?? ''}');
  if (port != null) out['port'] = port;
  applyXraySecurity(out, stream);
  final xhttp = _map(stream['xhttpSettings']);
  final extra = xhttp['extra'] is Map ? xhttp['extra'] as Map : xhttp;
  for (final key in const ['path', 'host']) {
    final v = '${xhttp[key] ?? ''}';
    if (v.isNotEmpty) out[key] = v;
  }
  if (_value(extra['headers']) case final headers?) out['headers'] = headers;
  final reuse = _renamed(_map(extra['xmux']), _xmuxKeys);
  if (reuse.isNotEmpty) out['reuse-settings'] = reuse;
  return out;
}
