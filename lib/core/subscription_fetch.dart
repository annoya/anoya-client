import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import 'app_error.dart';
import 'device_identity.dart';
import 'log.dart';
import 'parsers/provider_routing.dart';
import 'parsers/subscription.dart';
import 'subscription_info.dart';

class SubscriptionResponse {
  const SubscriptionResponse({
    required this.body,
    required this.info,
    required this.deviceLimitActive,
    required this.deviceLimitReached,
    this.routing,
    this.routingProbed = false,
    this.usedFallback = false,
    this.rendering = '',
    this.renderingProbed = false,
  });

  final String body;

  final SubscriptionInfo info;

  final bool deviceLimitActive;

  final bool deviceLimitReached;

  final ProviderRouting? routing;

  final bool routingProbed;

  SubscriptionResponse viaFallback() => _with(usedFallback: true);

  SubscriptionResponse _with({
    String? body,
    bool? usedFallback,
    String? rendering,
    bool? renderingProbed,
  }) => SubscriptionResponse(
    body: body ?? this.body,
    info: info,
    deviceLimitActive: deviceLimitActive,
    deviceLimitReached: deviceLimitReached,
    routing: routing,
    routingProbed: routingProbed,
    usedFallback: usedFallback ?? this.usedFallback,
    rendering: rendering ?? this.rendering,
    renderingProbed: renderingProbed ?? this.renderingProbed,
  );

  final String rendering;

  final bool renderingProbed;

  final bool usedFallback;
}

Future<SubscriptionResponse> fetchSubscription(
  String url, {
  http.Client? client,
  bool probeRouting = true,
  String fallbackUrl = '',
  Duration? timeout,
  String rendering = '',
  bool probeRenderings = true,
}) async {
  final uri = Uri.parse(url);
  final identity = await DeviceIdentityStore.load();
  final http.Client c = client ?? http.Client();
  final wait = _boundedTimeout(timeout);
  try {
    try {
      if (rendering.isNotEmpty) {
        final named = renderingUrl(uri, rendering);
        if (named != null) {
          try {
            final res = await _fetch(named, identity, c, probeRouting, wait);
            return res._with(rendering: rendering, renderingProbed: true);
          } catch (e) {
            Log.e(
              'named rendering failed, falling back to the plain address',
              '${uri.host}/$rendering: $e',
            );
          }
        }
      }
      final plain = await _fetch(uri, identity, c, probeRouting, wait);
      return await _withGroups(plain, uri, identity, c, wait, probeRenderings);
    } catch (e, stack) {
      final backup = Uri.tryParse(fallbackUrl);
      if (backup == null || backup.scheme != 'https' || backup.host.isEmpty) {
        rethrow;
      }
      Log.e(
        'subscription fetch failed, trying the backup address',
        '${uri.host} -> ${backup.host}',
      );
      try {
        final res = await _fetch(backup, identity, c, probeRouting, wait);
        return res.viaFallback();
      } catch (_) {
        Error.throwWithStackTrace(e, stack);
      }
    }
  } finally {
    if (client == null) c.close();
  }
}

Future<SubscriptionResponse> _fetch(
  Uri uri,
  DeviceIdentity identity,
  http.Client c,
  bool probeRouting,
  Duration timeout,
) async {
  final res = await c.get(uri, headers: identity.headers).timeout(timeout);

  final reached =
      _flag(res.headers, 'x-hwid-max-devices-reached') ||
      _flag(res.headers, 'x-hwid-limit');
  if (reached) {
    Log.e('subscription refused', 'device limit reached at ${uri.host}');
  }
  if (res.statusCode == 404 && _flag(res.headers, 'x-hwid-not-supported')) {
    throw AppErrorException(
      AppError(
        L10n.current.errorDeviceNotAcceptedTitle,
        detail: L10n.current.errorDeviceNotAcceptedDetail,
      ),
    );
  }
  if (res.statusCode ~/ 100 != 2) {
    throw http.ClientException(
      'subscription fetch failed (${res.statusCode})',
      Uri(host: uri.host),
    );
  }
  final (routing, probed) = await _providerRouting(uri, res, c, probeRouting);

  return SubscriptionResponse(
    body: res.body,
    info: SubscriptionInfo.fromHeaders(res.headers),
    deviceLimitActive: _flag(res.headers, 'x-hwid-active') || reached,
    deviceLimitReached: reached,
    routing: routing,
    routingProbed: probed,
  );
}

Future<SubscriptionResponse> _withGroups(
  SubscriptionResponse plain,
  Uri uri,
  DeviceIdentity identity,
  http.Client c,
  Duration wait,
  bool probe,
) async {
  if (!probe) return plain;
  if (_hasGroups(plain.body)) {
    return plain.renderingProbed ? plain : plain._with(renderingProbed: true);
  }

  for (final name in kClashRenderings) {
    final url = renderingUrl(uri, name);
    if (url == null) continue;
    try {
      final res = await _fetch(url, identity, c, false, wait);
      if (!_hasGroups(res.body)) continue;
      Log.i('subscription: using the $name rendering (it carries groups)');
      return res._with(rendering: name, renderingProbed: true);
    } catch (e) {
      Log.e('rendering not available', '${uri.host}/$name');
    }
  }
  return plain._with(renderingProbed: true);
}

bool _hasGroups(String body) =>
    RegExp(r'(^|\n)\s*proxy-groups\s*:').hasMatch(body) &&
    RegExp(r'(^|\n)\s*proxies\s*:').hasMatch(body);

const kClashRenderings = ['mihomo', 'clash-meta', 'clash'];

Uri? renderingUrl(Uri uri, String name) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  if (segments.first == 'sub' && segments.length >= 2) {
    if (name != 'clash') return null;
    return uri.replace(pathSegments: ['clash', ...segments.skip(1)]);
  }
  if (kSubscriptionRenderings.contains(segments.last.toLowerCase())) {
    return null;
  }
  return uri.replace(pathSegments: [...segments, name]);
}

Duration _boundedTimeout(Duration? asked) {
  if (asked == null) return kHttpTimeout;
  if (asked < kMinSubscriptionTimeout) return kMinSubscriptionTimeout;
  if (asked > kMaxSubscriptionTimeout) return kMaxSubscriptionTimeout;
  return asked;
}

const kMinSubscriptionTimeout = Duration(seconds: 5);
const kMaxSubscriptionTimeout = Duration(seconds: 15);

const kSubscriptionRenderings = {
  'json',
  'v2ray-json',
  'v2ray',
  'xray',
  'mihomo',
  'clash',
  'clash-meta',
  'stash',
  'singbox',
  'sing-box',
  'outline',
};

Future<(ProviderRouting?, bool)> _providerRouting(
  Uri uri,
  http.Response res,
  http.Client client,
  bool probeRouting,
) async {
  final header = res.headers['routing'];
  if (header != null && header.isNotEmpty) {
    final happ = parseHappRouting(header);
    if (happ != null) return (happ, true);
  }

  final body = res.body;
  if (RegExp(r'(^|\n)\s*rules\s*:').hasMatch(body)) {
    final clash = parseClashRouting(body);
    if (clash != null) return (clash, true);
  }

  if (!probeRouting) return (null, false);
  if (uri.pathSegments.isNotEmpty &&
      kSubscriptionRenderings.contains(uri.pathSegments.last.toLowerCase())) {
    return (null, true);
  }
  try {
    final identity = await DeviceIdentityStore.load();
    final jsonUri = uri.replace(path: '${uri.path}/json');
    final probe = await client
        .get(jsonUri, headers: identity.headers)
        .timeout(kHttpTimeout);
    if (probe.statusCode ~/ 100 != 2) return (null, true);
    final parsed = parseXrayRouting(probe.body);
    return (parsed, true);
  } catch (e) {
    Log.e('provider routing probe failed', '${uri.host}: $e');
    return (null, true);
  }
}

bool _flag(Map<String, String> headers, String name) {
  final v = headers[name]?.trim().toLowerCase();
  return v == 'true' || v == '1';
}

Future<ParsedSubscription?> fetchProxyProvider(
  ProxyProvider provider, {
  http.Client? client,
}) async {
  if (!provider.isValid) return null;
  final uri = Uri.parse(provider.url);
  final c = client ?? http.Client();
  try {
    final res = await c.get(uri).timeout(kHttpTimeout);
    if (res.statusCode ~/ 100 != 2) {
      throw http.ClientException('proxy list fetch failed (${res.statusCode})');
    }
    if (res.bodyBytes.length > kMaxProxyListBytes) {
      throw http.ClientException(
        'proxy list exceeds ${kMaxProxyListBytes ~/ 1024} KB',
      );
    }
    return parseSubscriptionBody(
      res.body,
      source: '${provider.name} @ ${uri.host}',
    );
  } catch (e) {
    Log.e('proxy list fetch failed', '${provider.name}: ${uri.host}: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}

const kMaxProxyListBytes = 4 * 1024 * 1024;

bool shouldProbeRenderings(String rendering) => rendering.isEmpty;
