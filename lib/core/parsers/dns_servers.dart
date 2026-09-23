import '../dns_plan.dart';
import '../log.dart';
import '../mihomo_tun_config.dart';

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

const _aliases = {'h3': 'https', 'h2c': 'http'};

String? mihomoNameserver(String address, {required bool viaTunnel}) {
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
