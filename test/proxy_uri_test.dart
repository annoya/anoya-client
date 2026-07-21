import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/proxy_uri.dart';

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
}
