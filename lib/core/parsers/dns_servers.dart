import '../log.dart';
import '../mihomo_tun_config.dart';

/// Turning one foreign DNS entry into a mihomo nameserver string.
///
/// The three JSON-ish formats each describe resolvers their own way, but they
/// agree on the two things that matter: *where* the resolver is, and *whether
/// the query is issued locally or sent out through the proxy*. Both have to
/// survive the translation — dropping the second is what turned a provider's
/// deliberate "keep DNS off the local network" into a leak, and copying it
/// verbatim is what deadlocked the engine (ADR-008).
///
/// This is a translation, not a field copy: sing-box names an outbound tag,
/// Xray marks a scheme `+local`, and neither of those names exists in the
/// config we render. What we can render is one outbound, [kTunnelOutbound], so
/// the question collapses to a boolean.

/// Values that name a *mechanism* rather than a server: the OS resolver, a
/// fake-IP responder, a canned rcode. None of them survives the trip into our
/// engine config, and the first one is actively dangerous — inside the Network
/// Extension the "system" resolver reads the tunnel's own DNS settings, so a
/// query to it comes straight back through `dns-hijack` to the engine that
/// asked. mihomo accepts these strings (anything without a scheme becomes
/// `udp://<it>`), which is exactly why they have to be stopped here: they parse
/// fine and then never answer.
const _mechanisms = {
  'local',
  'localhost',
  'system',
  'underlying',
  'fakeip',
  'fakedns',
  'hosts',
  'predefined',
  'resolved',
  'dhcp',
  'rcode',
  'tailscale',
  'ts',
};

/// Schemes that mean the same thing under another name. HTTP/3 is a transport
/// for DNS-over-HTTPS, not a protocol of its own; mihomo spells the choice
/// `prefer-h3` and rejects the scheme, and rejecting a scheme costs the *whole*
/// config, not just the entry (`config.Parse` returns an error and the tunnel
/// never starts).
const _aliases = {'h3': 'https', 'h2c': 'http'};

/// [address] in the source's own spelling, [viaTunnel] as the source meant it.
/// Null when this entry cannot become a nameserver we would want to send.
String? mihomoNameserver(String address, {required bool viaTunnel}) {
  // A fragment here would be the source's own outbound name, which we do not
  // render; [viaTunnel] already carries what it was trying to say.
  var s = address.trim().split('#').first.trim();
  if (s.isEmpty) return null;

  final at = s.indexOf('://');
  if (at < 0) {
    if (_mechanisms.contains(s.toLowerCase())) return null;
  } else {
    final scheme = s.substring(0, at).toLowerCase();
    if (_mechanisms.contains(scheme)) return null;
    final mapped = _aliases[scheme] ?? scheme;
    if (!kMihomoDnsSchemes.contains(mapped)) {
      Log.e('dns: unsupported resolver scheme', scheme);
      return null;
    }
    s = '$mapped://${s.substring(at + 3)}';
  }
  return viaTunnel ? '$s#$kTunnelOutbound' : s;
}
