import '../l10n/l10n.dart';
import 'json_file_store.dart';

class ConnectionCheckPrefs {
  const ConnectionCheckPrefs({
    this.enabled = true,
    this.url = defaultUrl,
    this.timeoutSeconds = 5,
  });

  static const defaultUrl = 'https://www.gstatic.com/generate_204';

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
  final first = raw
      .split('\n')
      .first
      .replaceFirst('connect failed: ', '')
      .trim();
  if (first.isEmpty) return l10n.connectionCheckNothingCameBack;
  return first.endsWith('.') ? first : '$first.';
}

class ConnectionCheck {
  const ConnectionCheck({
    required this.at,
    this.delayMs,
    this.failure,
    this.via = '',
    this.observed = false,
  });

  const ConnectionCheck.observed({required this.at, this.via = ''})
    : delayMs = null,
      failure = null,
      observed = true;

  final DateTime at;
  final int? delayMs;
  final String? failure;
  final bool observed;

  final String via;

  bool get passed => delayMs != null || observed;

  static int downloadedFrom(String counters) {
    final parts = counters.split(':');
    if (parts.length != 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

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
