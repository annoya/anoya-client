import 'dart:convert';

import 'log.dart';

/// What a subscription panel says about itself in the response headers.
///
/// A panel knows things the body cannot carry — how much of the plan is left,
/// when it ends, what it is called, how often to come back, where to get help.
/// Marzban established the convention and the rest of the ecosystem followed
/// it, so this is read from any panel, not detected per vendor.
///
/// None of it is authoritative. A subscription has no account behind it
/// (ADR-005): the panel controls access by changing what the URL returns, not
/// by telling us a verdict. These are its words, presented as such.
class SubscriptionInfo {
  const SubscriptionInfo({
    this.title = '',
    this.usedBytes = 0,
    this.totalBytes = 0,
    this.expiresAt,
    this.announce = '',
    this.supportUrl = '',
    this.webPageUrl = '',
    this.updateInterval,
    this.fallbackUrl = '',
    this.requestTimeout,
  });

  /// `profile-title` — what the provider calls this subscription.
  final String title;

  /// `subscription-userinfo`: upload + download, and the plan's ceiling.
  final int usedBytes;

  /// 0 means the panel declared no limit, not "nothing left".
  final int totalBytes;

  /// Null when the panel sent `expire=0`, i.e. no end date.
  final DateTime? expiresAt;

  /// `announce` — a message from the provider, shown verbatim as their voice.
  final String announce;

  /// `support-url` — where the provider wants questions to go.
  final String supportUrl;

  /// `profile-web-page-url` — the page a human is meant to open.
  final String webPageUrl;

  /// `profile-update-interval`, in days. Null when the panel did not say.
  /// How often the panel wants the subscription re-read, **in hours** — the
  /// convention's unit (Happ: "the interval is set in hours and must be a
  /// multiple of one hour"). Null when it said nothing.
  final int? updateInterval;

  /// Where to ask when the main address does not answer. A subscription URL
  /// like any other, so it is a credential: it never reaches a log or an error
  /// message beyond its host.
  final String fallbackUrl;

  /// How long the panel wants us to wait for it, in seconds. Bounded on use —
  /// a panel does not get to hold the app's refresh open for a minute.
  final int? requestTimeout;

  bool get hasPlan => usedBytes > 0 || totalBytes > 0 || expiresAt != null;
  bool get unlimited => totalBytes <= 0;
  bool get isEmpty =>
      !hasPlan &&
      title.isEmpty &&
      announce.isEmpty &&
      supportUrl.isEmpty &&
      webPageUrl.isEmpty;

  /// True once the panel's own end date has passed. Reported, never enforced:
  /// the panel keeps serving these servers, and refusing to connect would be
  /// deciding on behalf of the party that actually has that right.
  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
    if (title.isNotEmpty) 'title': title,
    if (usedBytes > 0) 'used_bytes': usedBytes,
    if (totalBytes > 0) 'total_bytes': totalBytes,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    if (announce.isNotEmpty) 'announce': announce,
    if (supportUrl.isNotEmpty) 'support_url': supportUrl,
    if (webPageUrl.isNotEmpty) 'web_page_url': webPageUrl,
    if (updateInterval != null) 'update_interval': updateInterval,
    if (fallbackUrl.isNotEmpty) 'fallback_url': fallbackUrl,
    if (requestTimeout != null) 'request_timeout': requestTimeout,
  };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
    title: j['title'] as String? ?? '',
    usedBytes: j['used_bytes'] as int? ?? 0,
    totalBytes: j['total_bytes'] as int? ?? 0,
    expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
    announce: j['announce'] as String? ?? '',
    supportUrl: j['support_url'] as String? ?? '',
    webPageUrl: j['web_page_url'] as String? ?? '',
    updateInterval: j['update_interval'] as int?,
    fallbackUrl: j['fallback_url'] as String? ?? '',
    requestTimeout: j['request_timeout'] as int?,
  );

  /// Reads the convention out of one response's headers.
  factory SubscriptionInfo.fromHeaders(Map<String, String> headers) {
    final user = _userInfo(headers['subscription-userinfo'] ?? '');
    final expire = user['expire'] ?? 0;
    return SubscriptionInfo(
      title: _text(headers['profile-title']),
      usedBytes: (user['upload'] ?? 0) + (user['download'] ?? 0),
      totalBytes: user['total'] ?? 0,
      // 0 is the convention's "no end date", not 1970.
      expiresAt: expire > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              expire * 1000,
              isUtc: true,
            ).toLocal()
          : null,
      announce: _text(headers['announce']),
      supportUrl: (headers['support-url'] ?? '').trim(),
      webPageUrl: (headers['profile-web-page-url'] ?? '').trim(),
      updateInterval: int.tryParse(
        (headers['profile-update-interval'] ?? '').trim(),
      ),
      // https only: this address decides which servers the app trusts, so it
      // does not arrive over a channel anyone can rewrite.
      fallbackUrl: _url(headers['fallback-url']),
      requestTimeout: int.tryParse(
        (headers['subscription-request-timeout'] ?? '').trim(),
      ),
    );
  }

  static String _url(String? raw) {
    final v = (raw ?? '').trim();
    final uri = Uri.tryParse(v);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? v : '';
  }

  /// A header that may arrive as `base64:<payload>` — the convention's way of
  /// carrying non-ASCII, and the usual case for a title or a message written
  /// in anything but English.
  static String _text(String? raw) {
    final v = (raw ?? '').trim();
    if (!v.startsWith('base64:')) return v;
    try {
      final payload = v.substring('base64:'.length);
      return utf8.decode(base64.decode(base64.normalize(payload))).trim();
    } catch (e) {
      Log.e('subscription header: undecodable base64', '$e');
      return '';
    }
  }

  /// `upload=0; download=123; total=0; expire=1785093975`
  static Map<String, int> _userInfo(String raw) {
    final out = <String, int>{};
    for (final part in raw.split(';')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final n = int.tryParse(kv[1].trim());
      if (n != null) out[kv[0].trim().toLowerCase()] = n;
    }
    return out;
  }
}
