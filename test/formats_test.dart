import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/parsers/share_link.dart';
import 'package:vpn_client/core/parsers/subscription.dart';

/// The four shapes a panel can answer with, and what we say when none of them
/// yields a server.
///
/// Reading one format and not another is not a missing feature the user can see
/// — it looks like an empty subscription. That is why the format itself is part
/// of the result, and why "we could not read this" and "we read it and can run
/// none of it" are different sentences.
void main() {
  group('xray json', () {
    // The shape a live Remnawave panel serves: a JSON array of whole configs,
    // one per server, each naming itself in `remarks`.
    const body = '''
[
  {"remarks": "🇩🇪 Germany",
   "outbounds": [
     {"tag": "proxy", "protocol": "vless",
      "settings": {"vnext": [{"address": "de.example", "port": 443,
        "users": [{"id": "uuid-1", "flow": "xtls-rprx-vision", "encryption": "none"}]}]},
      "streamSettings": {"network": "tcp", "security": "reality",
        "realitySettings": {"publicKey": "PK", "shortId": "s1", "serverName": "www.example",
          "fingerprint": "chrome"}}},
     {"tag": "direct", "protocol": "freedom"},
     {"tag": "block", "protocol": "blackhole"}
   ]},
  {"remarks": "🇳🇱 Netherlands",
   "outbounds": [
     {"tag": "proxy", "protocol": "trojan",
      "settings": {"servers": [{"address": "nl.example", "port": 8443, "password": "pw"}]},
      "streamSettings": {"network": "ws", "security": "tls",
        "tlsSettings": {"serverName": "nl.example", "alpn": ["h2", "http/1.1"]},
        "wsSettings": {"path": "/ws", "headers": {"Host": "nl.example"}}}}
   ]}
]''';

    test('every config in the array is one server, named by its remarks', () {
      final p = parseSubscriptionBody(body);
      expect(p.format, SubscriptionFormat.xray);
      expect(p.locations.map((l) => l.label), ['🇩🇪 Germany', '🇳🇱 Netherlands']);
    });

    test('reality, vision flow and fingerprint survive the translation', () {
      final de = parseSubscriptionBody(body).locations.first.proxy;
      expect(de['type'], 'vless');
      expect(de['server'], 'de.example');
      expect(de['port'], 443);
      expect(de['uuid'], 'uuid-1');
      expect(de['flow'], 'xtls-rprx-vision');
      expect(de['tls'], isTrue);
      expect(de['servername'], 'www.example');
      expect(de['client-fingerprint'], 'chrome');
      expect(de['reality-opts'], {'public-key': 'PK', 'short-id': 's1'});
    });

    test('the transport is mapped, not passed through', () {
      final nl = parseSubscriptionBody(body).locations[1].proxy;
      expect(nl['type'], 'trojan');
      expect(nl['network'], 'ws');
      expect(nl['sni'], 'nl.example', reason: 'trojan names it sni, not servername');
      expect(nl['alpn'], ['h2', 'http/1.1']);
      expect(nl['ws-opts'], {'path': '/ws', 'headers': {'Host': 'nl.example'}});
    });

    test('plumbing outbounds are not counted as unsupported servers', () {
      // freedom, blackhole and dns are how an Xray config expresses direct,
      // reject and its resolver — inventing a shortfall out of them would
      // accuse the panel of sending servers it never sent.
      expect(parseSubscriptionBody(body).unsupported, isEmpty);
    });

    test('a protocol we have no adapter for is counted, with its own name', () {
      const wg = '''
{"outbounds": [{"tag": "w", "protocol": "wireguard", "settings": {"peers": []}}]}''';
      final p = parseSubscriptionBody(wg);
      expect(p.format, SubscriptionFormat.xray);
      expect(p.locations, isEmpty);
      expect(p.unsupported, {'wireguard': 1});
    });
  });

  group('sing-box', () {
    const body = '''
{"outbounds": [
  {"tag": "→ Provider", "type": "selector", "outbounds": ["a", "b"]},
  {"tag": "a", "type": "vless", "server": "a.example", "server_port": 443, "uuid": "u1",
   "flow": "xtls-rprx-vision",
   "tls": {"enabled": true, "server_name": "sni.example", "utls": {"enabled": true,
     "fingerprint": "chrome"}, "reality": {"enabled": true, "public_key": "PK",
     "short_id": "s1"}}},
  {"tag": "b", "type": "hysteria2", "server": "b.example", "server_port": 8443,
   "password": "pw", "tls": {"enabled": true, "server_name": "b.example"},
   "obfs": {"type": "salamander", "password": "op"}},
  {"tag": "c", "type": "wireguard", "server": "c.example", "server_port": 51820},
  {"tag": "direct", "type": "direct"}
]}''';

    test('the selector is not a server', () {
      final p = parseSubscriptionBody(body);
      expect(p.format, SubscriptionFormat.singbox);
      expect(p.locations.map((l) => l.label), ['a', 'b']);
      expect(p.unsupported, {'wireguard': 1});
    });

    test('reality and utls are read out of the single tls object', () {
      final a = parseSubscriptionBody(body).locations.first.proxy;
      expect(a['tls'], isTrue);
      expect(a['servername'], 'sni.example');
      expect(a['client-fingerprint'], 'chrome');
      expect(a['reality-opts'], {'public-key': 'PK', 'short-id': 's1'});
      expect(a['flow'], 'xtls-rprx-vision');
    });

    test('hysteria2 keeps its obfuscation', () {
      final b = parseSubscriptionBody(body).locations[1].proxy;
      expect(b['type'], 'hysteria2');
      expect(b['sni'], 'b.example');
      expect(b['obfs'], 'salamander');
      expect(b['obfs-password'], 'op');
    });

    test('tls off means tls off', () {
      // The one mistake that produces a config which looks right and fails at
      // the handshake.
      const plain = '''
{"outbounds": [{"tag": "p", "type": "vmess", "server": "p.example",
  "server_port": 80, "uuid": "u", "security": "auto"}]}''';
      expect(parseSubscriptionBody(plain).locations.single.proxy['tls'], isFalse);
    });

    test('http transport means HTTP/2 here, which the engine calls h2', () {
      const h2 = '''
{"outbounds": [{"tag": "p", "type": "vless", "server": "p.example", "server_port": 443,
  "uuid": "u", "tls": {"enabled": true},
  "transport": {"type": "http", "path": "/p", "host": ["p.example"]}}]}''';
      final proxy = parseSubscriptionBody(h2).locations.single.proxy;
      expect(proxy['network'], 'h2');
      expect(proxy['h2-opts'], isNotNull);
    });
  });

  group('shadowsocks plugins', () {
    test('simple-obfs becomes the engine\'s obfs plugin', () {
      const link =
          'ss://YWVzLTI1Ni1nY206cHc@h.example:8388?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dbing.com#SS';
      final proxy = parseShareLink(link).location!.proxy;
      expect(proxy['plugin'], 'obfs');
      expect(proxy['plugin-opts'], {'mode': 'http', 'host': 'bing.com'});
    });

    test('v2ray-plugin carries its websocket options', () {
      const link =
          'ss://YWVzLTI1Ni1nY206cHc@h.example:8388?plugin=v2ray-plugin%3Bmode%3Dwebsocket%3Btls%3Bhost%3Dh.example%3Bpath%3D%2Fws#SS';
      final proxy = parseShareLink(link).location!.proxy;
      expect(proxy['plugin'], 'v2ray-plugin');
      expect(proxy['plugin-opts'],
          {'mode': 'websocket', 'host': 'h.example', 'path': '/ws', 'tls': true});
    });

    test('a plugin the engine cannot run is reported, not dropped', () {
      // Dropping it leaves a server in the list that always fails: the server
      // expects obfuscation the client is not doing.
      const link = 'ss://YWVzLTI1Ni1nY206cHc@h.example:8388?plugin=shadow-tls%3Bhost%3Dx#SS';
      expect(parseShareLink(link).unsupported, 'ss+shadow-tls');
      const bad = 'ss://YWVzLTI1Ni1nY206cHc@h.example:8388?plugin=obfs-local%3Bobfs%3Dquic#SS';
      expect(parseShareLink(bad).unsupported, 'ss+obfs (quic)');
    });

    test('a plain ss link is unaffected', () {
      const link = 'ss://YWVzLTI1Ni1nY206cHc@h.example:8388#SS';
      final proxy = parseShareLink(link).location!.proxy;
      expect(proxy.containsKey('plugin'), isFalse);
      expect(proxy['cipher'], 'aes-256-gcm');
    });
  });

  group('what the user is told when nothing came out', () {
    test('a Clash document with an empty list is Clash, not unreadable', () {
      // A live panel answers this way for an account with nothing assigned. The
      // format is fine; there is simply nothing in it, and the fix is with the
      // provider rather than with the app.
      final p = parseSubscriptionBody('proxies: []\nrules:\n  - MATCH,DIRECT\n');
      expect(p.format, SubscriptionFormat.clash);
      expect(p.locations, isEmpty);
      expect(p.unsupported, isEmpty);
    });

    test('a body we cannot identify is unknown, not an empty link list', () {
      for (final body in [
        '<!doctype html><html><body>Not found</body></html>',
        '{"error": "unauthorized"}',
        'complete nonsense',
      ]) {
        final p = parseSubscriptionBody(body);
        expect(p.format, SubscriptionFormat.unknown, reason: body);
        expect(p.locations, isEmpty);
      }
    });

    test('a readable body full of things we cannot run says which', () {
      const body = 'tuic://x@h:443#a\ntuic://y@h:443#b\nssr://zzz#c';
      final p = parseSubscriptionBody(body);
      expect(p.format, SubscriptionFormat.links);
      expect(p.locations, isEmpty);
      expect(p.unsupported, {'tuic': 2, 'ssr': 1});
      expect(p.total, 3, reason: 'the panel offered three, we can run none');
    });

    test('entries that point nowhere are a message, not servers', () {
      // A live panel's answer to a client it does not recognise: valid links to
      // unroutable addresses whose names carry the text.
      const body = 'vless://u@0.0.0.0:1?security=none#Приложение%20не%20поддерживается\n'
          'vless://u@127.0.0.1:1?security=none#Используйте%20Happ';
      final p = parseSubscriptionBody(body);
      expect(p.locations.length, 2);
      expect(p.allPlaceholders, isTrue);
      expect(p.placeholderLines,
          ['Приложение не поддерживается', 'Используйте Happ']);
    });

    test('one real server among placeholders is not a message', () {
      const body = 'vless://u@0.0.0.0:1?security=none#msg\n'
          'vless://u@real.example:443?security=reality&pbk=PK#DE';
      expect(parseSubscriptionBody(body).allPlaceholders, isFalse);
    });
  });

  group('clash proxy-providers', () {
    test('a document that only points at its servers is still a subscription', () {
      const body = '''
proxy-providers:
  main:
    type: http
    url: "https://lists.example/proxies.yaml"
    interval: 3600
  local:
    type: file
    path: ./p.yaml
  insecure:
    type: http
    url: "http://lists.example/p.yaml"
''';
      final p = parseSubscriptionBody(body);
      expect(p.format, SubscriptionFormat.clash);
      expect(p.providers.map((e) => e.name), ['main'],
          reason: 'a file lives on the author\'s disk and http can be rewritten');
      expect(p.locations, isEmpty, reason: 'the fetch belongs to the network layer');
    });
  });
}
