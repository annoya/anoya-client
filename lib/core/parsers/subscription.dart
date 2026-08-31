import '../amnezia/vpn_key.dart';
import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';
import 'clash_config.dart';
import 'singbox_config.dart';
import 'xray_config.dart';
import 'share_link.dart';


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
    this.providers = const [],
    this.groups = const [],
    this.dns = const [],
    this.format = SubscriptionFormat.unknown,
  });

  final List<Location> locations;

  /// What was recognisably a server and how many of it we could not run, keyed
  /// by the name the body used — a URI scheme (`tuic`) or a Clash `type`
  /// (`wireguard`). That is what the user is told, because it is what they can
  /// look up.
  final Map<String, int> unsupported;

  /// Server lists this body points at instead of carrying. Fetched and merged
  /// by the caller — see [ProxyProvider].
  final List<ProxyProvider> providers;

  /// Sets whose member the engine picks, offered by this body.
  final List<ProxyGroup> groups;

  /// The resolvers this body wants used while connected, already translated
  /// into mihomo's nameserver syntax — including the pin that says whether a
  /// query rides the tunnel. Read here rather than by a second pass over the
  /// body: which format this is has just been decided, and asking again would
  /// mean guessing it a second time from a different angle.
  ///
  /// Empty for a link list, which has nowhere to put one, and for a body whose
  /// DNS block named nothing we could send. The renderer's fallback covers it.
  final List<String> dns;

  /// Which shape this body turned out to be. Needed for the message when there
  /// is nothing usable in it: "we could not read this" and "we read it and
  /// cannot run any of it" send the user to two different places.
  final SubscriptionFormat format;

  int get unsupportedCount => unsupported.values.fold(0, (a, b) => a + b);

  /// How many servers the body offered, ours and not.
  int get total => locations.length + unsupportedCount;

  bool get hasUnsupported => unsupported.isNotEmpty;

  /// Every entry points nowhere — the shape a panel uses to say something to a
  /// client it does not want to serve: valid links whose addresses are
  /// unroutable and whose *names* are the message.
  ///
  /// Only meaningful when there is at least one entry: an empty list is not a
  /// message, it is an empty list.
  bool get allPlaceholders =>
      locations.isNotEmpty && locations.every((l) => _isUnroutable('${l.proxy['server']}'));

  /// The text such a panel sent, which is the entries' own names.
  List<String> get placeholderLines => locations.map((l) => l.label).toList();

  /// "hysteria2, tuic" — for saying which, not how many.
  String get unsupportedList {
    final kinds = unsupported.keys.toList()..sort();
    return kinds.join(', ');
  }
}

/// The shapes a panel can answer with. All four of the template families the
/// panels ship (base64 links, Clash/mihomo, Xray JSON, sing-box) plus the one
/// that matters most for the message: none of them.
enum SubscriptionFormat {
  links,
  clash,
  xray,
  singbox,

  /// Not a server list we can read. An HTML error page, a format we have no
  /// parser for, or a body that is simply not what its provider thinks it is.
  unknown;

  /// What the user is told it was. Only reached when nothing usable came out,
  /// so it names the format rather than describing it.
  String get label => switch (this) {
        SubscriptionFormat.links => 'a link list',
        SubscriptionFormat.clash => 'a Clash / mihomo subscription',
        SubscriptionFormat.xray => 'an Xray JSON subscription',
        SubscriptionFormat.singbox => 'a sing-box subscription',
        SubscriptionFormat.unknown => 'something unrecognised',
      };
}

/// Parse a subscription body in whichever of the four formats it is.
///
/// Order is by how cheaply a format identifies itself, and every parser returns
/// null rather than guessing: `proxies:` makes it Clash, `protocol` inside
/// `outbounds` makes it Xray, `type` inside `outbounds` makes it sing-box, and
/// a `://` anywhere makes it a link list.
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

  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    final xray = parseXrayServers(trimmed);
    if (xray != null) return xray;
    final singbox = parseSingboxServers(trimmed);
    if (singbox != null) return singbox;
  }

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
  return ParsedSubscription(
    locations: out,
    unsupported: unsupported,
    // A body with no link and nothing recognisable in it is not "an empty link
    // list", it is a body we failed to identify — and the difference is the
    // whole point of the message the user gets.
    format: out.isEmpty && unsupported.isEmpty
        ? SubscriptionFormat.unknown
        : SubscriptionFormat.links,
  );
}

/// Just the servers, for the callers that only need those.
List<Location> parseSubscription(String body) => parseSubscriptionBody(body).locations;

/// Just the resolvers, for the callers that only need those.
List<String> subscriptionDns(String body) => parseSubscriptionBody(body).dns;


/// What a pasted string on the add screen turned out to be — drives the live
/// detection chip and enables Continue.
enum InputKind {
  /// A single share link (vless:// etc.) → a link profile.
  link,

  /// An Amnezia `vpn://` subscription key. Its servers are not in the key —
  /// the gateway issues them — so this is the one input whose Continue has to
  /// reach the network before there is anything to show.
  amneziaKey,

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
  // Before the share-link check: `vpn://` is Amnezia's, and the formats this
  // app does not serve (their self-hosted bundles, the retired v1) are refused
  // here rather than misread as something else later.
  if (scheme == 'vpn') {
    final key = parseAmneziaVpnKey(t);
    return key == null
        ? null
        : DetectedInput(InputKind.amneziaKey, '${key.name} · subscription key');
  }
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

/// Addresses that cannot be dialed anywhere. A server on one of these was
/// never meant to be connected to.
bool _isUnroutable(String host) {
  final h = host.trim().toLowerCase();
  return h == '0.0.0.0' ||
      h == '127.0.0.1' ||
      h == 'localhost' ||
      h == '::' ||
      h == '::1' ||
      h.startsWith('127.');
}

/// A server list a Clash document points at rather than carrying.
///
/// The engine can fetch these itself and, as with rule lists, is not allowed
/// to: it would do it while applying a config and report failure by logging
/// (ADR-005). We fetch them, so an unreachable list is a fact we can state.
class ProxyProvider {
  const ProxyProvider({required this.name, required this.url});

  final String name;
  final String url;

  /// Over TLS or not at all: this list decides which servers the user's traffic
  /// goes to, so it does not arrive over a channel anyone can rewrite.
  bool get isValid {
    final uri = Uri.tryParse(url);
    return name.isNotEmpty && uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
