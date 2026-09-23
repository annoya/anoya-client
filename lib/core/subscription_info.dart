import 'dart:convert';

import 'log.dart';

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

  final String title;

  final int usedBytes;

  final int totalBytes;

  final DateTime? expiresAt;

  final String announce;

  final String supportUrl;

  final String webPageUrl;

  final int? updateInterval;

  final String fallbackUrl;

  final int? requestTimeout;

  bool get hasPlan => usedBytes > 0 || totalBytes > 0 || expiresAt != null;
  bool get unlimited => totalBytes <= 0;
  bool get isEmpty =>
      !hasPlan &&
      title.isEmpty &&
      announce.isEmpty &&
      supportUrl.isEmpty &&
      webPageUrl.isEmpty;

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
