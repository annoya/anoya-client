import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/pipe_transport.dart';

void main() {
  late FakeLink link;
  late PipeTransport t;

  setUp(() {
    link = FakeLink();
    t = PipeTransport(() => link, retryDelay: const Duration(milliseconds: 20));
  });
  tearDown(() => t.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a request is one JSON line and its answer is matched by id', () async {
    await link.connected;
    await settle();
    final res = t.invoke<String>('proxy_bytes');
    final sent = jsonDecode(link.lines.single) as Map;
    expect(sent['method'], 'proxy_bytes');
    expect(sent['args'], {});
    link.feed({'id': sent['id'], 'result': '10:20'});
    expect(await res, '10:20');
  });

  test('a refusal is a PlatformException with the service\'s words', () async {
    await link.connected;
    await settle();
    final res = t.invoke<void>('reload', {'config': 'x'});
    final sent = jsonDecode(link.lines.single) as Map;
    expect(sent['args'], {'config': 'x'});
    link.feed({
      'id': sent['id'],
      'result': null,
      'error': 'tunnel is not running',
    });
    await expectLater(
      res,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.message,
          'message',
          'tunnel is not running',
        ),
      ),
    );
  });

  test('status events reach the stream, split from partial chunks', () async {
    await link.connected;
    final seen = <String?>[];
    final sub = t.statusEvents.listen(seen.add);
    final a = utf8.encode('{"event":"status","status":"connec');
    final b = utf8.encode('ting"}\n{"event":"status","status":"connected"}\n');
    link.push(a);
    link.push(b);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['connecting', 'connected']);
    await sub.cancel();
  });

  test(
    'without a service every request fails as unavailable, and the status says so',
    () async {
      t.dispose();
      link = FakeLink(refuse: true);
      t = PipeTransport(
        () => link,
        retryDelay: const Duration(milliseconds: 20),
      );
      final seen = <String?>[];
      final sub = t.statusEvents.listen(seen.add);
      await expectLater(
        t.invoke<String>('version'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'service_unavailable',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, contains('disconnected'));
      await sub.cancel();
    },
  );

  test(
    'the service going away fails what was waiting and reconnects',
    () async {
      await link.connected;
      await settle();
      final seen = <String?>[];
      final sub = t.statusEvents.listen(seen.add);
      final res = t.invoke<String>('url_test', {'url': 'https://x'});
      final first = link;
      final next = FakeLink();
      link = next;
      await first.hangUp();
      await expectLater(
        res,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'service_disconnected',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        'disconnected',
      ], reason: 'a vanished service is a down tunnel');
      await next.connected;
      next.feed({'event': 'status', 'status': 'connected'});
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.last,
        'connected',
        reason: 'the reconnection carries the live status',
      );
      await sub.cancel();
    },
  );
}

class FakeLink implements PipeLink {
  FakeLink({this.refuse = false});
  final bool refuse;
  final lines = <String>[];
  final _in = StreamController<List<int>>();
  final _connected = Completer<void>();
  Future<void> get connected => _connected.future;

  @override
  Stream<List<int>> get incoming => _in.stream;

  void push(List<int> bytes) => _in.add(bytes);
  Future<void> hangUp() => _in.close();

  @override
  Future<void> connect() async {
    if (refuse) throw StateError('no such pipe');
    _connected.complete();
  }

  void feed(Map<String, Object?> msg) =>
      _in.add(utf8.encode('${jsonEncode(msg)}\n'));

  @override
  void write(List<int> bytes) => lines.add(utf8.decode(bytes).trimRight());

  @override
  void close() {}
}
