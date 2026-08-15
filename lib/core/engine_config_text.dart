/// Everything this app knows about putting untrusted text into the engine's
/// YAML config lives here.
///
/// The config is assembled as text and executed by the engine, and parts of it
/// come from places we do not control: subscription bodies, share links, the
/// rule editor. Two layers use these rules and must agree, which is why they
/// are stated once:
///
///  - the parser (`proxy_uri.dart`) drops what it cannot vouch for,
///  - the renderer (`mihomo_tun_config.dart`) quotes what it emits.
///
/// See AGENTS.md invariant 5.
library;

/// Characters a mihomo config key may consist of: kebab-case option names
/// (`skip-cert-verify`), dotted ones, and HTTP header names (`User-Agent`).
///
/// Keys are *structural* — they decide the config's shape, not just a value —
/// so this is deliberately narrower than "anything that survives quoting". A
/// key carrying a newline would escape its block and add a top-level option
/// (`external-controller` publishes an unauthenticated control API), which is
/// why such keys are dropped at the parser rather than escaped anywhere.
final _configKey = RegExp(r'^[A-Za-z0-9._-]+$');

/// Whether [key] is plainly a config key and may be emitted as-is.
bool isSafeConfigKey(String key) => _configKey.hasMatch(key);

/// A YAML scalar: always double-quoted, with the two characters that can end
/// or continue a quoted string escaped. Quoting unconditionally (rather than
/// only when it looks necessary) keeps the rule easy to verify — there is no
/// "did we need quotes here?" judgement anywhere in the renderer.
String yamlScalar(dynamic value) {
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  final s = value.toString().replaceAll('\\', r'\\').replaceAll('"', r'\"');
  return '"$s"';
}

/// A YAML mapping key. Safe keys stay bare so the output reads like a normal
/// config; anything else is quoted, so a key that slipped past the parser
/// still cannot introduce a line of its own.
String yamlKey(String key) => isSafeConfigKey(key) ? key : yamlScalar(key);
