import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/parsers/share_link.dart';
import 'package:vpn_client/core/parsers/subscription.dart';

void main() {
  test('vless reality link → mihomo proxy', () {
    final loc = parseProxyUri(
      'vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443'
      '?security=reality&sni=www.apple.com&flow=xtls-rprx-vision&pbk=PUBKEY&sid=abcd&fp=chrome&type=tcp#Tokyo')!;
    expect(loc.label, 'Tokyo');
    final p = loc.proxy;
    expect(p['type'], 'vless');
    expect(p['server'], '1.2.3.4');
    expect(p['port'], 443);
    expect(p['uuid'], '11111111-2222-3333-4444-555555555555');
    expect(p['tls'], true);
    expect(p['flow'], 'xtls-rprx-vision');
    expect(p['servername'], 'www.apple.com');
    expect(p['client-fingerprint'], 'chrome');
    expect((p['reality-opts'] as Map)['public-key'], 'PUBKEY');
    expect((p['reality-opts'] as Map)['short-id'], 'abcd');
  });

  test('vless ws+tls link', () {
    final loc = parseProxyUri(
      'vless://uuid-x@example.com:443?security=tls&type=ws&path=/vpn&host=cdn.example.com&sni=cdn.example.com')!;
    final p = loc.proxy;
    expect(p['network'], 'ws');
    expect((p['ws-opts'] as Map)['path'], '/vpn');
    expect(((p['ws-opts'] as Map)['headers'] as Map)['Host'], 'cdn.example.com');
    expect(p['label'], isNull); // label lives on Location, not proxy
    expect(loc.label, 'example.com:443'); // no fragment → host:port
  });

  test('vless percent-encoded fragment (flag emoji) is decoded', () {
    // #🇩🇪 h2.nexus  (as delivered in a real subscription line)
    final loc = parseProxyUri(
      'vless://uuid-x@1.2.3.4:443?type=tcp'
      '#%F0%9F%87%A9%F0%9F%87%AA%20h2.nexus%20')!;
    expect(loc.label, '🇩🇪 h2.nexus');
  });

  test('vmess base64 json link', () {
    final json = base64.encode(utf8.encode(jsonEncode({
      'v': '2', 'ps': 'VM', 'add': '9.9.9.9', 'port': '8443', 'id': 'vmess-uuid',
      'aid': '0', 'scy': 'auto', 'net': 'ws', 'host': 'h.example.com', 'path': '/p', 'tls': 'tls', 'sni': 's.example.com',
    })));
    final loc = parseProxyUri('vmess://$json')!;
    final p = loc.proxy;
    expect(loc.label, 'VM');
    expect(p['type'], 'vmess');
    expect(p['server'], '9.9.9.9');
    expect(p['port'], 8443);
    expect(p['uuid'], 'vmess-uuid');
    expect(p['alterId'], 0);
    expect(p['tls'], true);
    expect(p['servername'], 's.example.com');
    expect((p['ws-opts'] as Map)['path'], '/p');
  });

  test('trojan link', () {
    final loc = parseProxyUri('trojan://secretpass@t.example.com:443?sni=t.example.com#Tj')!;
    final p = loc.proxy;
    expect(p['type'], 'trojan');
    expect(p['password'], 'secretpass');
    expect(p['sni'], 't.example.com');
    expect(loc.label, 'Tj');
  });

  test('shadowsocks SIP002 link', () {
    final userinfo = base64Url.encode(utf8.encode('aes-256-gcm:mypassword')).replaceAll('=', '');
    final loc = parseProxyUri('ss://$userinfo@5.5.5.5:8388#SS')!;
    final p = loc.proxy;
    expect(p['type'], 'ss');
    expect(p['server'], '5.5.5.5');
    expect(p['port'], 8388);
    expect(p['cipher'], 'aes-256-gcm');
    expect(p['password'], 'mypassword');
  });

  test('unknown scheme / garbage → null', () {
    expect(parseProxyUri('http://example.com'), isNull);
    expect(parseProxyUri('not a link'), isNull);
  });

  test('subscription: base64 list of links', () {
    final list = 'vless://u1@1.1.1.1:443?security=reality&pbk=K#A\n'
        'trojan://pw@2.2.2.2:443#B';
    final b64 = base64.encode(utf8.encode(list));
    final locs = parseSubscription(b64);
    expect(locs.length, 2);
    expect(locs[0].label, 'A');
    expect(locs[1].proxy['type'], 'trojan');
  });

  test('subscription: Clash YAML proxies pass through', () {
    const yaml = '''
proxies:
  - name: "SG"
    type: vless
    server: sg.example.com
    port: 443
    uuid: abc
    tls: true
    servername: sg.example.com
    network: ws
    ws-opts:
      path: /ray
  - name: "US"
    type: ss
    server: us.example.com
    port: 8388
    cipher: aes-256-gcm
    password: pw
rules:
  - MATCH,DIRECT
''';
    final locs = parseSubscription(yaml);
    expect(locs.length, 2);
    expect(locs[0].label, 'SG');
    expect(locs[0].proxy['type'], 'vless');
    expect((locs[0].proxy['ws-opts'] as Map)['path'], '/ray');
    expect(locs[1].proxy['cipher'], 'aes-256-gcm');
  });
  test('an IPv6 literal loses its brackets, whichever form carried it', () {
    // ss:// carries host:port as text; vless:// goes through Uri, which
    // already strips them. Both must land on the bare address.
    final ss = parseProxyUri('ss://YWVzLTEyOC1nY206cGFzcw==@[2001:db8::1]:8388#v6')!;
    expect(ss.proxy['server'], '2001:db8::1');
    final vless = parseProxyUri('vless://uuid@[2001:db8::2]:443?security=tls#v6')!;
    expect(vless.proxy['server'], '2001:db8::2');
  });

  test('a proxy with an unusable port is rejected, not emitted with port 0', () {
    // {"add":"1.2.3.4","port":"bad","id":"x"} — a vmess payload whose port is
    // not a number at all.
    expect(parseProxyUri('vmess://eyJhZGQiOiIxLjIuMy40IiwicG9ydCI6ImJhZCIsImlkIjoieCJ9'), isNull);
    expect(parseProxyUri('vless://uuid@host:99999?security=tls'), isNull);
  });

  test('an oversized subscription body is refused before parsing', () {
    final huge = 'vless://uuid@host:443#x\n' * 200000;
    expect(huge.length, greaterThan(4 * 1024 * 1024));
    expect(parseSubscription(huge), isEmpty);
  });

  group('hysteria2', () {
    test('a hysteria2 link becomes a mihomo hysteria2 proxy', () {
      // The shape a live panel sends: password in the userinfo, sni + alpn +
      // insecure in the query, and no transport — it is QUIC.
      final loc = parseProxyUri(
          'hysteria2://s3cret@de.example.com:30443/?sni=de.example.com&alpn=h3&insecure=0#DE')!;
      expect(loc.proxy['type'], 'hysteria2');
      expect(loc.proxy['server'], 'de.example.com');
      expect(loc.proxy['port'], 30443);
      expect(loc.proxy['password'], 's3cret');
      expect(loc.proxy['sni'], 'de.example.com');
      expect(loc.proxy['alpn'], ['h3'], reason: 'a list in mihomo, comma-separated in the URI');
      expect(loc.proxy.containsKey('skip-cert-verify'), isFalse,
          reason: 'insecure=0 must not become skip-cert-verify');
      expect(loc.label, 'DE');
    });

    test('the hy2:// alias is the same protocol', () {
      final loc = parseProxyUri('hy2://pw@h.example:443?sni=h.example')!;
      expect(loc.proxy['type'], 'hysteria2');
    });

    test('insecure=1, obfs and port hopping are carried through', () {
      final loc = parseProxyUri(
          'hy2://pw@h.example:443?insecure=1&obfs=salamander&obfs-password=o&mport=30000-31000')!;
      expect(loc.proxy['skip-cert-verify'], isTrue);
      expect(loc.proxy['obfs'], 'salamander');
      expect(loc.proxy['obfs-password'], 'o');
      expect(loc.proxy['ports'], '30000-31000', reason: 'mport is the other spelling');
    });

    test('multiple alpn values stay a list', () {
      final loc = parseProxyUri('hy2://pw@h.example:443?alpn=h3,http/1.1')!;
      expect(loc.proxy['alpn'], ['h3', 'http/1.1']);
    });
  });

  group('unsupported servers are counted, not dropped in silence', () {
    test('a link list reports what it could not use, by scheme', () {
      final parsed = parseSubscriptionBody([
        'vless://u@a.example:443?security=tls',
        'hysteria2://p@b.example:443',
        'tuic://p@c.example:443',
        'anytls://p@d.example:443',
        'tuic://p@e.example:443',
        '# a comment, not a server',
      ].join('\n'));
      expect(parsed.locations, hasLength(2), reason: 'vless and hysteria2 are ours');
      expect(parsed.unsupported, {'tuic': 2, 'anytls': 1});
      expect(parsed.total, 5, reason: 'the comment is noise, not a skipped server');
      expect(parsed.unsupportedList, 'anytls, tuic');
    });

    test('a Clash body drops what the engine cannot render, and says so', () {
      // Left in, these would reach the server picker and fail only on Connect.
      final parsed = parseSubscriptionBody('proxies:\n'
          '  - {name: ok, type: vless, server: a.example, port: 443, uuid: u}\n'
          '  - {name: wg, type: wireguard, server: b.example, port: 51820}\n'
          '  - {name: tu, type: tuic, server: c.example, port: 443}\n');
      expect(parsed.locations.map((l) => l.label), ['ok']);
      expect(parsed.unsupported, {'wireguard': 1, 'tuic': 1});
      expect(parsed.total, 3);
    });

    test('a body of nothing but unsupported servers is still accounted for', () {
      final parsed = parseSubscriptionBody('tuic://p@c.example:443');
      expect(parsed.locations, isEmpty);
      expect(parsed.unsupported, {'tuic': 1});
    });
  });

  group('transports the engine expresses differently from the URI', () {
    test('tcp with an HTTP header is a different network, not plain tcp', () {
      // Dropping the header used to leave network: tcp — a server expecting
      // HTTP obfuscation then refuses, with the server still listed as fine.
      final loc = parseProxyUri(
          'vless://u@h.example:443?security=tls&type=tcp&headerType=http&path=/p&host=h.example')!;
      expect(loc.proxy['network'], 'http');
      expect((loc.proxy['http-opts'] as Map)['path'], ['/p'],
          reason: 'a list in the engine, one value in the URI');
      expect(((loc.proxy['http-opts'] as Map)['headers'] as Map)['Host'], ['h.example']);
    });

    test('httpupgrade is a websocket with the handshake skipped', () {
      final loc = parseProxyUri(
          'vless://u@h.example:443?security=tls&type=httpupgrade&path=/up&host=h.example')!;
      expect(loc.proxy['network'], 'ws', reason: 'the engine has no separate network for it');
      final ws = loc.proxy['ws-opts'] as Map;
      expect(ws['path'], '/up');
      expect(ws['v2ray-http-upgrade'], isTrue);
    });

    test('xhttp carries its path, host and mode', () {
      final loc = parseProxyUri(
          'vless://u@h.example:443?security=tls&type=xhttp&path=/x&host=h.example&mode=packet-up')!;
      expect(loc.proxy['network'], 'xhttp');
      expect(loc.proxy['xhttp-opts'], {'path': '/x', 'host': 'h.example', 'mode': 'packet-up'});
    });

    test('an xhttp server with a split download channel is refused, not guessed', () {
      // Two channels dialed as one fails in a way no message could explain, so
      // it is counted as unsupported instead.
      final r = parseShareLink('vless://u@h.example:443?security=tls&type=xhttp&path=/x'
          '&extra=%7B%22downloadSettings%22%3A%7B%22address%22%3A%22d.example%22%7D%7D');
      expect(r.location, isNull);
      expect(r.unsupported, contains('xhttp'));
    });

    test('a transport the engine has no adapter for is named, not degraded', () {
      final r = parseShareLink('vless://u@h.example:443?security=tls&type=kcp&mtu=1350');
      expect(r.location, isNull);
      expect(r.unsupported, 'kcp');
    });

    test('trojan is held to what the engine allows it', () {
      // The engine's trojan adapter carries only ws and grpc; emitting xhttp
      // for it would produce a config it rejects.
      expect(parseShareLink('trojan://p@h.example:443?type=xhttp&path=/x').unsupported, 'xhttp');
      expect(parseShareLink('trojan://p@h.example:443?type=ws&path=/w').location, isNotNull);
    });

    test('a malformed link of a known scheme is junk, not an unsupported protocol', () {
      // "vless unsupported" would be a lie, and would put vless in the count
      // the user is shown.
      final r = parseShareLink('vless://u@h.example:99999?security=tls');
      expect(r.location, isNull);
      expect(r.unsupported, isNull);
    });
  });

  group('TLS parameters that decide whether the handshake succeeds', () {
    test('alpn is carried for vless and trojan, as a list', () {
      // A server expecting h2 refuses a client that offers nothing else.
      expect(parseProxyUri('vless://u@h.example:443?security=tls&alpn=h2,http/1.1')!.proxy['alpn'],
          ['h2', 'http/1.1']);
      expect(parseProxyUri('trojan://p@h.example:443?alpn=h3')!.proxy['alpn'], ['h3']);
    });

    test('post-quantum reality is passed through', () {
      final loc = parseProxyUri(
          'vless://u@h.example:443?security=reality&pbk=K&sid=00&pqv=1')!;
      expect((loc.proxy['reality-opts'] as Map)['support-x25519mlkem768'], isTrue,
          reason: 'ignoring the flag silently negotiates the classical curve');
    });

    test('a fingerprint on trojan is not dropped', () {
      expect(parseProxyUri('trojan://p@h.example:443?fp=chrome')!.proxy['client-fingerprint'],
          'chrome');
    });
  });

  test('unsupported transports are counted by transport, not by protocol', () {
    final parsed = parseSubscriptionBody([
      'vless://u@a.example:443?security=tls&type=ws&path=/w',
      'vless://u@b.example:443?security=tls&type=kcp',
      'vless://u@c.example:443?security=tls&type=kcp',
      'trojan://p@d.example:443?type=xhttp',
      'tuic://p@e.example:443',
    ].join('\n'));
    expect(parsed.locations, hasLength(1));
    expect(parsed.unsupported, {'kcp': 2, 'xhttp': 1, 'tuic': 1},
        reason: 'vless is supported; its transport was not — say which');
    expect(parsed.total, 5);
  });


  group('base64 payloads on vless:// and trojan://', () {
    // Not a standard form for either protocol, but panels and older clients
    // emit it — the whole URI body encoded, sometimes with the name outside.
    String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
    const uuid = 'd1f8b2c4-aaaa-bbbb-cccc-1234567890ab';

    test('base64 of the URI body is read as the URI', () {
      final loc = parseProxyUri(
          'vless://${b64('$uuid@h.example:443?security=tls&type=ws&path=/x&sni=h.example#Tokyo')}')!;
      expect(loc.proxy['server'], 'h.example');
      expect(loc.proxy['uuid'], uuid);
      expect(loc.proxy['network'], 'ws');
      expect(loc.proxy['servername'], 'h.example');
      expect(loc.label, 'Tokyo');
    });

    test('a name outside the base64 wins over one inside', () {
      final loc = parseProxyUri('vless://${b64('$uuid@h.example:443?security=tls#inner')}#Outer')!;
      expect(loc.label, 'Outer');
    });

    test('the vmess-style JSON form carries vless fields too', () {
      final json = jsonEncode({
        'add': 'r.example', 'port': 443, 'id': uuid, 'net': 'tcp', 'tls': 'reality',
        'sni': 'www.example', 'fp': 'chrome', 'pbk': 'PK', 'sid': 's1',
        'flow': 'xtls-rprx-vision', 'ps': 'Reality',
      });
      final loc = parseProxyUri('vless://${b64(json)}')!;
      expect(loc.proxy['type'], 'vless');
      expect(loc.proxy['uuid'], uuid);
      expect(loc.proxy['tls'], isTrue);
      expect(loc.proxy['servername'], 'www.example');
      expect(loc.proxy['flow'], 'xtls-rprx-vision');
      expect(loc.proxy['client-fingerprint'], 'chrome');
      expect(loc.proxy['reality-opts'], {'public-key': 'PK', 'short-id': 's1'});
      expect(loc.proxy, isNot(contains('alterId')), reason: 'a vmess field, not a vless one');
      expect(loc.label, 'Reality');
    });

    test('trojan takes the same wrapping', () {
      final loc = parseProxyUri('trojan://${b64('pw@t.example:443?sni=t.example#Tj')}')!;
      expect(loc.proxy['password'], 'pw');
      expect(loc.proxy['server'], 't.example');
      expect(loc.proxy['sni'], 't.example');
      expect(loc.label, 'Tj');
    });

    test('base64 that decodes to nothing link-like is malformed, and the reason names no payload', () {
      final r = parseShareLink('vless://${b64('just some words')}');
      expect(r.location, isNull);
      expect(r.malformed, isNotNull);
      expect(r.malformed, isNot(contains('just')));
    });

    test('the plain URI form is untouched by the unwrapping', () {
      final loc = parseProxyUri('vless://$uuid@h.example:443?security=tls#Plain')!;
      expect(loc.proxy['uuid'], uuid);
      expect(loc.label, 'Plain');
    });

    test('the add screen recognises the wrapped link as a server', () {
      final d = detectInput('vless://${b64('$uuid@h.example:443?security=tls#Tokyo')}');
      expect(d!.kind, InputKind.link);
      expect(d.label, contains('Tokyo'));
    });
  });

}

