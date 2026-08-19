import 'package:yaml/yaml.dart';

import '../engine_config_text.dart';
import '../log.dart';
import '../norm_config.dart';
import 'base64_text.dart';

/// Clash / mihomo YAML, the second shape a subscription body arrives in.
///
/// Unlike a share link, the proxy entries here are already mihomo-shaped maps
/// with keys chosen by whoever wrote the document — which is why key sanitation
/// (AGENTS invariant 5) lives in this file and not in the renderer alone.

List<Location>? parseClashProxies(String body) {
  if (!RegExp(r'(^|\n)\s*proxies\s*:').hasMatch(body)) return null;
  try {
    final doc = loadYaml(body);
    if (doc is! Map || doc['proxies'] is! List) return null;
    final out = <Location>[];
    var i = 0;
    for (final p in (doc['proxies'] as List)) {
      final m = _deepConvert(p);
      if (m is! Map<String, dynamic> || m['type'] == null || m['server'] == null) continue;
      final name = m['name']?.toString() ?? '${m['server']}:${m['port']}';
      out.add(Location(id: 'sub_${i++}_${shortDigest(name)}', label: name, proxy: m));
    }
    return out.isEmpty ? null : out;
  } catch (e) {
    Log.e('clash yaml parse failed', '$e');
    return null;
  }
}


/// Resolvers a Clash/mihomo-YAML subscription ships in `dns.nameserver`;
/// empty for link lists and anything unparseable. Mined separately from the
/// proxies because our tunnel config keeps its own dns block (fake-ip range
/// and mode are app constants) and adopts only the resolvers.
List<String> subscriptionDns(String body) {
  final trimmed = body.trim();
  if (!RegExp(r'(^|\n)\s*dns\s*:').hasMatch(trimmed)) return const [];
  try {
    final doc = loadYaml(trimmed);
    if (doc is! Map) return const [];
    final dns = doc['dns'];
    if (dns is! Map) return const [];
    final ns = dns['nameserver'];
    if (ns is! List) return const [];
    return [
      for (final e in ns)
        if (e != null && '$e'.trim().isNotEmpty) '$e'.trim(),
    ];
  } catch (e) {
    Log.e('subscription dns parse failed', '$e');
    return const [];
  }
}


/// Recursively converts YamlMap/YamlList into plain `Map<String,dynamic>`/List.
///
/// A Clash/mihomo-YAML subscription is attacker-supplied (ADR-005), and its map
/// keys flow into the engine config we render. A key carrying a newline would
/// break out of its block and add top-level keys (`external-controller`,
/// `allow-lan`…), so keys that are not plainly a config key are dropped here —
/// the drop-not-escape stance ADR-003/ADR-008 take for values, extended to keys.
dynamic _deepConvert(dynamic node) {
  if (node is YamlMap || node is Map) {
    final out = <String, dynamic>{};
    for (final e in (node as Map).entries) {
      final k = e.key.toString();
      if (!isSafeConfigKey(k)) {
        Log.e('clash yaml: dropped unsafe proxy key', k.replaceAll('\n', r'\n'));
        continue;
      }
      out[k] = _deepConvert(e.value);
    }
    return out;
  }
  if (node is YamlList || node is List) {
    return [for (final e in (node as List)) _deepConvert(e)];
  }
  return node;
}

