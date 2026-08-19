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

/// The outcome of reading one subscription body: the servers we can run, and
/// an account of the ones we cannot.
///
/// The count matters as much as the list. A panel shows the user 306 servers;
/// if the app shows 294 and says nothing, the twelve missing ones read as a bug
/// in the app — or worse, as the provider shortchanging them. Naming what was
/// skipped turns a silent discrepancy into a fact with a reason.
class ParsedSubscription {
  const ParsedSubscription({
    required this.locations,
    this.unsupported = const {},
  });

  final List<Location> locations;

  /// What was recognisably a server and how many of it we could not run, keyed
  /// by the name the body used — a URI scheme (`tuic`) or a Clash `type`
  /// (`wireguard`). That is what the user is told, because it is what they can
  /// look up.
  final Map<String, int> unsupported;

  int get unsupportedCount => unsupported.values.fold(0, (a, b) => a + b);

  /// How many servers the body offered, ours and not.
  int get total => locations.length + unsupportedCount;

  bool get hasUnsupported => unsupported.isNotEmpty;

  /// "hysteria2, tuic" — for saying which, not how many.
  String get unsupportedList {
    final kinds = unsupported.keys.toList()..sort();
    return kinds.join(', ');
  }
}

/// Parse a subscription body: Clash/mihomo YAML (has `proxies:`) or a (usually
/// base64-encoded) newline/whitespace-separated list of share links.
ParsedSubscription parseSubscriptionBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const ParsedSubscription(locations: []);
  if (trimmed.length > _maxSubscriptionChars) {
    Log.e('subscription rejected', 'body too large (${trimmed.length} chars)');
    return const ParsedSubscription(locations: []);
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
  final unsupported = <String, int>{};
  for (final line in text.split(RegExp(r'[\r\n\s]+'))) {
    if (line.isEmpty) continue;
    final parsed = parseShareLink(line);
    final loc = parsed.location;
    if (loc != null) {
      out.add(loc);
      continue;
    }
    // The parser names what stopped it — a scheme we have no protocol for, or a
    // transport the engine cannot run. Junk (a comment, a stray token) is not
    // counted: it was never a server, and counting it would accuse the panel of
    // losing one.
    final why = parsed.unsupported;
    if (why != null && why.length <= 24) {
      unsupported[why] = (unsupported[why] ?? 0) + 1;
    }
  }
  return ParsedSubscription(locations: out, unsupported: unsupported);
}

/// Just the servers, for the callers that only need those.
List<Location> parseSubscription(String body) => parseSubscriptionBody(body).locations;


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
  if (singleToken && kShareLinkSchemes.contains(scheme)) {
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

