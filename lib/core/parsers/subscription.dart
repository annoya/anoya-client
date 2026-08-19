import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'clash_config.dart';
import 'share_link.dart';

/// The DNS a Clash-YAML body declares is a property of the subscription, not of
/// the YAML parser, so it is part of this façade.
export 'clash_config.dart' show subscriptionDns;

/// A subscription body: whatever a panel returns for a subscription URL.
///
/// This file owns only the question "which format is this?" — the formats
/// themselves live in [share_link.dart] and [clash_config.dart]. Bodies are
/// attacker-supplied (ADR-005): a panel is a third party, and an unparseable
/// or hostile body must cost us a log line, not a crash.

/// Ceiling on a subscription body. A real one is kilobytes; anything past this
/// is a mistake or a hostile server, and both parsers below (base64, YAML)
/// build their whole result in memory.
const _maxSubscriptionChars = 4 * 1024 * 1024;

/// Parse a subscription body: Clash/mihomo YAML (has `proxies:`) or a (usually
/// base64-encoded) newline/whitespace-separated list of share links.
List<Location> parseSubscription(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return [];
  if (trimmed.length > _maxSubscriptionChars) {
    Log.e('subscription rejected', 'body too large (${trimmed.length} chars)');
    return [];
  }

  // Clash/mihomo YAML?
  final clash = parseClashProxies(trimmed);
  if (clash != null) return clash;

  // Otherwise a link list — possibly base64-wrapped.
  var text = trimmed;
  if (!text.contains('://')) {
    final decoded = tryDecodeLooseBase64(text);
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

