import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secrets.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    memorySecrets.clear();
    useMemorySecrets();
  });
  await testMain();
}
