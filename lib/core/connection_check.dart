import '../l10n/l10n.dart';
import 'json_file_store.dart';

/// What the app asks the engine after a connect, and what it does with the
/// answer.
///
/// The system's "connected" is a claim about an interface, not about a path: an
/// AmneziaWG peer whose handshake never completes and a VLESS server that
/// accepts TCP and then says nothing both leave a tunnel that looks up and
/// carries nothing. The check is one HTTP HEAD through the selected outbound —
/// mihomo's own `Proxy.URLTest`, the mechanism url-test groups pick members
/// with.
class ConnectionCheckPrefs {
  const ConnectionCheckPrefs({
    this.enabled = true,
    this.url = defaultUrl,
    this.timeoutSeconds = 5,
  });

  /// mihomo's own default. A 204 with no body is the cheapest possible answer
  /// and the least likely to be rewritten by something in between.
  static const defaultUrl = 'https://www.gstatic.com/generate_204';

  /// On by default: it costs one HEAD per connect and catches the one failure
  /// the interface cannot report. Off is a real choice — the request goes to
  /// somebody else's host every time the tunnel comes up.
  final bool enabled;
  final String url;
  final int timeoutSeconds;

  Duration get timeout => Duration(seconds: timeoutSeconds);

  ConnectionCheckPrefs copyWith({
    bool? enabled,
    String? url,
    int? timeoutSeconds,
  }) => ConnectionCheckPrefs(
    enabled: enabled ?? this.enabled,
    url: url ?? this.url,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
  );

  factory ConnectionCheckPrefs.fromJson(Map<String, dynamic> j) =>
      ConnectionCheckPrefs(
        enabled: j['enabled'] as bool? ?? true,
        url: (j['url'] as String?)?.isNotEmpty == true
            ? j['url'] as String
            : defaultUrl,
        timeoutSeconds: j['timeout_seconds'] as int? ?? 5,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'url': url,
    'timeout_seconds': timeoutSeconds,
  };
}

class ConnectionCheckStore {
  static final _store = JsonFileStore('connection_check.json');

  static Future<ConnectionCheckPrefs> load() => _store.load(
    (j) => j is Map
        ? ConnectionCheckPrefs.fromJson(Map<String, dynamic>.from(j))
        : const ConnectionCheckPrefs(),
    const ConnectionCheckPrefs(),
  );

  static Future<void> save(ConnectionCheckPrefs prefs) =>
      _store.save(prefs.toJson());
}

/// The engine's failure, said in words the reader can act on.
///
/// Go hands us its dial chain verbatim — `connect failed: dial tcp
/// 172.253.144.94:443: context deadline exceeded`, and often a second line for
/// the IPv6 attempt of the same request. Every part of that is about our
/// plumbing: the address belongs to somebody else's CDN, "dial" is a verb from
/// the dialer, and the two lines are one question asked twice. What the reader
/// needs is which of the three things happened — nothing came back, the server
/// hung up, or it was never reached. The engine's own text stays in the log.
String describeProbeFailure(String raw) {
  final l10n = L10n.current;
  final text = raw.toLowerCase();
  if (text.contains('deadline exceeded') || text.contains('timeout')) {
    return l10n.connectionCheckTimedOut;
  }
  if (text.contains('eof') || text.contains('connection reset')) {
    return l10n.connectionCheckClosed;
  }
  if (text.contains('refused')) return l10n.connectionCheckRefused;
  if (text.contains('no outbound named')) {
    return l10n.connectionCheckNoServer;
  }
  if (text.contains('not running')) return l10n.connectionCheckTunnelNotRunning;
  // Anything we have not seen keeps the engine's own first line rather than
  // being folded into "something went wrong": an unexplained sentence the user
  // can quote is worth more than a tidy one that fits every failure.
  final first = raw
      .split('\n')
      .first
      .replaceFirst('connect failed: ', '')
      .trim();
  if (first.isEmpty) return l10n.connectionCheckNothingCameBack;
  return first.endsWith('.') ? first : '$first.';
}

/// One answer from the engine, kept for the screen to show and compare.
///
/// A pass carries the delay because the number is the point: "143 ms" and
/// "1.9 s" answer different questions, and the second only reads next to the
/// first. A failure carries a sentence rather than a code — the codes come
/// from Go error strings and mean nothing to whoever is reading them.
class ConnectionCheck {
  const ConnectionCheck({
    required this.at,
    this.delayMs,
    this.failure,
    this.via = '',
    this.observed = false,
  });

  /// The tunnel was found working without asking anything: traffic the user
  /// was making anyway had already come back through the server.
  ///
  /// Kept apart from a measured pass because it carries no number, and
  /// inventing one for the sake of a uniform line would be a lie about what we
  /// did.
  const ConnectionCheck.observed({required this.at, this.via = ''})
    : delayMs = null,
      failure = null,
      observed = true;

  final DateTime at;
  final int? delayMs;
  final String? failure;
  final bool observed;

  /// Which server the probe actually went through. A group picks its own
  /// member, so a delay without a name measures something unidentified.
  final String via;

  bool get passed => delayMs != null || observed;

  /// Reads the `<up>:<down>` counters. Zero and unparseable are the same
  /// answer — nothing to look at.
  static int downloadedFrom(String counters) {
    final parts = counters.split(':');
    if (parts.length != 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  /// Parses the engine's answer: `ms:<delay>` or `err:<reason>`.
  ///
  /// One string in both directions because that is what the tunnel transports
  /// speak on both platforms — and because a delay of 0 is otherwise
  /// indistinguishable from a failure.
  factory ConnectionCheck.parse(
    String answer, {
    required DateTime at,
    String via = '',
  }) {
    if (answer.startsWith('ms:')) {
      final ms = int.tryParse(answer.substring(3));
      if (ms != null) return ConnectionCheck(at: at, delayMs: ms, via: via);
    }
    final reason = answer.startsWith('err:') ? answer.substring(4) : answer;
    return ConnectionCheck(
      at: at,
      failure: reason.trim().isEmpty
          ? L10n.current.connectionCheckEngineDidNotAnswer
          : describeProbeFailure(reason),
      via: via,
    );
  }
}
