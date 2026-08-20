import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_client/core/norm_config.dart';
import 'package:vpn_client/core/rule_list_store.dart';

/// The files a provider's rule lists live in.
///
/// What matters here is the boundary with the engine: mihomo would fetch these
/// itself, inside config apply, and report failure by logging. Everything below
/// exists so that the app knows what it holds before the engine is told
/// anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory container;

  const reject = RuleList(
    name: 'reject',
    url: 'https://lists.example/reject.yaml',
    behavior: 'domain',
  );
  const other = RuleList(
    name: 'ads',
    url: 'https://lists.example/ads.txt',
    behavior: 'classical',
    format: 'text',
  );

  setUp(() {
    container = Directory.systemTemp.createTempSync('vpn-rulelists');
    messenger.setMockMethodCallHandler(
      const MethodChannel('vpn/control'),
      (call) async => call.method == 'shared_dir' ? container.path : null,
    );
    RuleListStore.debugReset();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('vpn/control'), null);
    container.deleteSync(recursive: true);
  });

  Future<File> place(RuleList list, String content) async {
    final path = (await RuleListStore.pathFor(list))!;
    final f = File(path);
    await f.writeAsString(content);
    return f;
  }

  test('a list we do not hold is not available, and says nothing more', () async {
    final status = await RuleListStore.status(const [reject]);
    expect(status.single.available, isFalse);
    expect(status.single.bytes, 0);
  });

  test('a list on disk is reported with its size', () async {
    await place(reject, 'payload:\n  - "+.ads.example"\n');
    final status = await RuleListStore.status(const [reject]);
    expect(status.single.available, isTrue);
    expect(status.single.bytes, greaterThan(0));
    expect(status.single.updatedAt, isNotNull);
  });

  test('the file lives inside the engine home dir, under its own name',
      () async {
    // Inside the container because mihomo refuses a path outside its home
    // (`IsSafePath`); named by a digest of the URL because two providers can
    // publish different lists under the same name.
    final a = (await RuleListStore.pathFor(reject))!;
    final b = (await RuleListStore.pathFor(other))!;
    expect(a, startsWith('${container.path}/${RuleListStore.dirName}/'));
    expect(a, endsWith('.yaml'));
    expect(b, endsWith('.text'),
        reason: 'bookkeeping only — the engine reads the format from the config');
    expect(a, isNot(b));
  });

  test('the path for a URL does not move between runs', () async {
    // A refresh has to overwrite the file the running config already names.
    expect(await RuleListStore.pathFor(reject), await RuleListStore.pathFor(reject));
  });

  test('only lists we hold are offered to the renderer', () async {
    await place(reject, 'payload: []\n');
    final paths = await RuleListStore.availablePaths(const [reject, other]);
    expect(paths.keys, ['reject']);
    expect(paths['reject'], await RuleListStore.pathFor(reject));
  });

  test('pruning keeps what is still referenced and drops the rest', () async {
    await place(reject, 'a');
    await place(other, 'b');
    final stray = File('${container.path}/${RuleListStore.dirName}/leftover.yaml.tmp');
    await stray.writeAsString('half a download');

    await RuleListStore.prune(const [reject]);

    expect(await File((await RuleListStore.pathFor(reject))!).exists(), isTrue);
    expect(await File((await RuleListStore.pathFor(other))!).exists(), isFalse);
    expect(await stray.exists(), isFalse,
        reason: 'nothing points at a half-written file');
  });

  test('a list the app cannot validate is never fetched', () async {
    // http, not https: a rule list decides where traffic goes, so it does not
    // arrive over a channel anyone can rewrite.
    const insecure = RuleList(
        name: 'x', url: 'http://lists.example/l.yaml', behavior: 'domain');
    expect(insecure.isValid, isFalse);
    final status = await RuleListStore.sync(const [insecure]);
    expect(status.single.available, isFalse);
  });
}
