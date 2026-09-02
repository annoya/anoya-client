import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'app_error.dart';
import 'device_identity.dart';
import 'log.dart';
import 'parsers/provider_routing.dart';
import 'parsers/subscription.dart';
import 'subscription_info.dart';

/// One fetch of a subscription URL: the body, plus what the panel said about
/// this device.
///
/// A panel answers with more than a list of servers — it also reports whether
/// it counts devices and whether this one fits. That is not decoration: with a
/// device limit in force, a subscription that used to work simply stops
/// refreshing, and without reading these headers the app could only say "could
/// not refresh".
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

  /// What the panel said about the plan, itself and how to reach it.
  final SubscriptionInfo info;

  /// The panel told us it identifies devices (`x-hwid-active`). Only then does
  /// it make sense to tell the user this device occupies a slot.
  final bool deviceLimitActive;

  /// The panel refused this device because the subscription is full.
  final bool deviceLimitReached;

  /// Routing the panel wants applied, if it sent any. Null means it said
  /// nothing — not that it wants everything direct.
  final ProviderRouting? routing;

  /// A routing probe was made and came back empty, so there is no point
  /// repeating it every five minutes.
  final bool routingProbed;

  /// The same answer, marked as having come from the backup address.
  SubscriptionResponse viaFallback() => _with(usedFallback: true);

  SubscriptionResponse _with({
    String? body,
    bool? usedFallback,
    String? rendering,
    bool? renderingProbed,
  }) =>
      SubscriptionResponse(
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

  /// Which named rendering answered, if the plain URL was not the one used
  /// ('mihomo', 'clash-meta', …). Empty when the panel's own choice was taken.
  final String rendering;

  /// The renderings were tried and none of them carried groups, so there is no
  /// point asking again on every refresh.
  final bool renderingProbed;

  /// The main address did not answer and this came from the provider's backup.
  /// Worth telling the user: a provider whose main domain is blocked for good
  /// otherwise looks untouched, while they are down to one road of two.
  final bool usedFallback;
}

/// GET a subscription, identifying this device the way panels expect.
///
/// The identification headers go on every subscription request, not only where
/// we know they are needed: a panel that ignores them is unaffected, while a
/// panel that requires them answers 404 without them (see [DeviceIdentity]).
///
/// Errors carry the host only, never the full URL: a subscription URL is a
/// bearer-style credential, and exceptions from this path get logged and
/// shipped in the support archive verbatim.
///
/// [client] exists so a test can answer with the headers a panel would send;
/// production always uses the default.
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
      // A rendering that worked before is asked for directly: it is where the
      // servers, the groups and the rules came from last time, and going back
      // to the plain URL first would fetch a body we are about to discard.
      if (rendering.isNotEmpty) {
        final named = renderingUrl(uri, rendering);
        if (named != null) {
          try {
            final res = await _fetch(named, identity, c, probeRouting, wait);
            return res._with(rendering: rendering, renderingProbed: true);
          } catch (e) {
            // The panel dropped the template, or the path stopped working. The
            // plain URL is what the user added, so it is the answer of record.
            Log.e('named rendering failed, falling back to the plain address',
                '${uri.host}/$rendering: $e');
          }
        }
      }
      final plain = await _fetch(uri, identity, c, probeRouting, wait);
      return await _withGroups(plain, uri, identity, c, wait, probeRenderings);
    } catch (e, stack) {
      // The backup address exists for exactly this: the main one is blocked or
      // down. Tried once, and only when the provider named one — a retry loop
      // against a dead host is not resilience, it is a slower failure.
      final backup = Uri.tryParse(fallbackUrl);
      if (backup == null || backup.scheme != 'https' || backup.host.isEmpty) rethrow;
      Log.e('subscription fetch failed, trying the backup address',
          '${uri.host} -> ${backup.host}');
      try {
        final res = await _fetch(backup, identity, c, probeRouting, wait);
        return res.viaFallback();
      } catch (_) {
        // Both are gone: the message names the address the user added. The
        // backup is the provider's arrangement — an address the user has never
        // seen, and naming it would be a diagnosis they cannot act on. That the
        // backup was tried is in the log line above.
        Error.throwWithStackTrace(e, stack);
      }
    }
  } finally {
    // Closed once, after the routing lookup as well: a client closed between
    // the two requests fails the second one, and the failure looks exactly like
    // a panel with no routing to publish.
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

  final reached = _flag(res.headers, 'x-hwid-max-devices-reached') ||
      _flag(res.headers, 'x-hwid-limit'); // the older name, still sent
  if (reached) {
    // Reported, not thrown. The panel answers a refused device with a body of
    // its own — placeholder entries whose names carry its message — and
    // throwing here would discard exactly the thing the user needs to read.
    // The caller shows the message and takes the body as the new truth: the
    // subscription now returns this, and pretending otherwise would leave the
    // app showing servers the provider has stopped offering it.
    Log.e('subscription refused', 'device limit reached at ${uri.host}');
  }
  // A panel that enforces device limits answers 404 when the request carries
  // no id. We always send one, so this means the id was rejected rather than
  // missing — worth naming, because "not found" would send the user looking at
  // their URL.
  if (res.statusCode == 404 && _flag(res.headers, 'x-hwid-not-supported')) {
    throw const AppErrorException(AppError(
      'Your subscription did not accept this device',
      detail: 'It requires a device id this app did send. Ask your subscription’s support.',
    ));
  }
  if (res.statusCode ~/ 100 != 2) {
    throw http.ClientException(
        'subscription fetch failed (${res.statusCode})', Uri(host: uri.host));
  }
  final (routing, probed) = await _providerRouting(uri, res, c, probeRouting);

  return SubscriptionResponse(
    body: res.body,
    info: SubscriptionInfo.fromHeaders(res.headers),
    // A panel that refuses a device is a panel that counts them, whether or
    // not it also set the flag that says so.
    deviceLimitActive: _flag(res.headers, 'x-hwid-active') || reached,
    deviceLimitReached: reached,
    routing: routing,
    routingProbed: probed,
  );
}

/// Asks the panel for a Clash rendering when the body it chose has no groups.
///
/// Which body a panel serves is decided by a rule its admin wrote against our
/// User-Agent, so what we get is their choice about a client they may never
/// have heard of. Every panel that has renderings also lets a client name one,
/// which is the honest way to ask for the format our engine speaks — and the
/// only one that carries `proxy-groups`.
///
/// Costs one request, once: the outcome is remembered on the profile either
/// way. The plain body is kept whenever nothing better answers, because it is
/// what the user's provider decided to send them.
Future<SubscriptionResponse> _withGroups(
  SubscriptionResponse plain,
  Uri uri,
  DeviceIdentity identity,
  http.Client c,
  Duration wait,
  bool probe,
) async {
  if (!probe) return plain;
  if (_hasGroups(plain.body)) return plain.renderingProbed ? plain : plain._with(renderingProbed: true);

  for (final name in kClashRenderings) {
    final url = renderingUrl(uri, name);
    if (url == null) continue;
    try {
      final res = await _fetch(url, identity, c, false, wait);
      if (!_hasGroups(res.body)) continue;
      Log.i('subscription: using the $name rendering (it carries groups)');
      return res._with(rendering: name, renderingProbed: true);
    } catch (e) {
      // A 404 is the normal answer from a panel that has no such rendering.
      Log.e('rendering not available', '${uri.host}/$name');
    }
  }
  return plain._with(renderingProbed: true);
}

bool _hasGroups(String body) =>
    RegExp(r'(^|\n)\s*proxy-groups\s*:').hasMatch(body) &&
    RegExp(r'(^|\n)\s*proxies\s*:').hasMatch(body);

/// The names each panel gives its Clash/mihomo rendering, in the order they are
/// tried. Remnawave calls it `mihomo`, Marzban `clash-meta` (it has no
/// "mihomo"); 3x-ui serves it from a different path prefix instead, which
/// [renderingUrl] handles.
const kClashRenderings = ['mihomo', 'clash-meta', 'clash'];

/// The URL that asks for one named rendering, or null when this address cannot
/// express it.
Uri? renderingUrl(Uri uri, String name) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  // 3x-ui: the format is a path prefix, not a suffix — /sub/<id> next to
  // /clash/<id> and /json/<id>.
  if (segments.first == 'sub' && segments.length >= 2) {
    if (name != 'clash') return null;
    return uri.replace(pathSegments: ['clash', ...segments.skip(1)]);
  }
  if (kSubscriptionRenderings.contains(segments.last.toLowerCase())) return null;
  return uri.replace(pathSegments: [...segments, name]);
}

/// What the panel asked us to wait, bounded by what the app is willing to.
///
/// A panel that asks for a minute would hold a manual refresh — and the user
/// staring at it — open for that long; one that asks for a second would fail on
/// any slow link. The window is the convention's own (5–15 s), and no header
/// means our default.
Duration _boundedTimeout(Duration? asked) {
  if (asked == null) return kHttpTimeout;
  if (asked < kMinSubscriptionTimeout) return kMinSubscriptionTimeout;
  if (asked > kMaxSubscriptionTimeout) return kMaxSubscriptionTimeout;
  return asked;
}

const kMinSubscriptionTimeout = Duration(seconds: 5);
const kMaxSubscriptionTimeout = Duration(seconds: 15);

/// Renderings a panel serves the same subscription as, named in the URL's last
/// segment. A URL that already asks for one is not asked to render itself
/// again.
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

/// Finds the panel's routing, in the three places it turns up.
///
/// Two are free — a `routing:` header, or the `rules:` of a body that is already
/// Clash YAML. The third costs a request: some panels put their rules only in
/// the Xray-JSON rendering of the same subscription, and never in the format
/// they serve us. Remnawave lets a client ask for a rendering by name
/// (`<url>/<clientType>`), which is how that is fetched — by asking plainly,
/// not by pretending to be another app.
///
/// Returns (routing, probed): `probed` records that the paid-for request was
/// made and found nothing, so the poll does not repeat it every five minutes.
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
  // Not for a URL that already names a rendering, or we would be asking for
  // "<something>/json/json".
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


/// Header flags arrive as "true" (and, in the wild, as "1").
bool _flag(Map<String, String> headers, String name) {
  final v = headers[name]?.trim().toLowerCase();
  return v == 'true' || v == '1';
}

/// Fetches one `proxy-providers` list and reads the servers out of it.
///
/// Same rules as the subscription itself — TLS only, a timeout, a size ceiling —
/// because it is the same kind of thing: a third party naming the servers our
/// traffic will go to. Returns null when it cannot be had, which the caller
/// reports rather than hides.
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
      throw http.ClientException('proxy list exceeds ${kMaxProxyListBytes ~/ 1024} KB');
    }
    return parseSubscriptionBody(res.body, source: '${provider.name} @ ${uri.host}');
  } catch (e) {
    // Host only: a provider URL can carry a token of its own.
    Log.e('proxy list fetch failed', '${provider.name}: ${uri.host}: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// A proxy list is a few hundred entries of YAML at most. Past this it is not a
/// proxy list any more, and we are being fed something else.
const kMaxProxyListBytes = 4 * 1024 * 1024;

/// Whether a refresh should go looking for a better rendering.
///
/// Only the *positive* outcome of a past probe is worth remembering: a
/// rendering that answered is fetched directly and there is nothing left to
/// look for. "Nothing answered" used to be remembered just as firmly, and that
/// was the wrong asymmetry — a 404 during one bad minute pinned the
/// subscription to its plain body for good. For a panel like Remnawave that
/// body is a base64 link list: no groups, and no `rules:` either, so the policy
/// falls through to the Xray probe and arrives as a fraction of itself. Nothing
/// in the interface could undo it, refresh included.
///
/// The price of asking again is up to three 404s per refresh for a panel that
/// genuinely has no Clash rendering. The price of not asking is a configuration
/// that is quietly worse forever, which is not a trade.
bool shouldProbeRenderings(String rendering) => rendering.isEmpty;
