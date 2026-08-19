import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'app_error.dart';
import 'device_identity.dart';
import 'log.dart';
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
  });

  final String body;

  /// What the panel said about the plan, itself and how to reach it.
  final SubscriptionInfo info;

  /// The panel told us it identifies devices (`x-hwid-active`). Only then does
  /// it make sense to tell the user this device occupies a slot.
  final bool deviceLimitActive;

  /// The panel refused this device because the subscription is full.
  final bool deviceLimitReached;
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
Future<SubscriptionResponse> fetchSubscription(String url, {http.Client? client}) async {
  final uri = Uri.parse(url);
  final identity = await DeviceIdentityStore.load();
  final http.Client c = client ?? http.Client();
  final http.Response res;
  try {
    res = await c.get(uri, headers: identity.headers).timeout(kHttpTimeout);
  } finally {
    if (client == null) c.close();
  }

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
      'Your provider did not accept this device',
      detail: 'It requires a device id this app did send. Contact your provider.',
    ));
  }
  if (res.statusCode ~/ 100 != 2) {
    throw http.ClientException(
        'subscription fetch failed (${res.statusCode})', Uri(host: uri.host));
  }
  return SubscriptionResponse(
    body: res.body,
    info: SubscriptionInfo.fromHeaders(res.headers),
    // A panel that refuses a device is a panel that counts them, whether or
    // not it also set the flag that says so.
    deviceLimitActive: _flag(res.headers, 'x-hwid-active') || reached,
    deviceLimitReached: reached,
  );
}

/// Header flags arrive as "true" (and, in the wild, as "1").
bool _flag(Map<String, String> headers, String name) {
  final v = headers[name]?.trim().toLowerCase();
  return v == 'true' || v == '1';
}
