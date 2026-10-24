import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final memorySecrets = <String, String>{};

Future<Object?> memorySecretsHandler(MethodCall call) async {
  final args = (call.arguments as Map?) ?? const {};
  final key = args['key'] as String?;
  switch (call.method) {
    case 'read':
      return memorySecrets[key];
    case 'write':
      memorySecrets[key!] = args['value'] as String;
    case 'delete':
      memorySecrets.remove(key);
    case 'containsKey':
      return memorySecrets.containsKey(key);
    case 'readAll':
      return Map<String, String>.of(memorySecrets);
    case 'deleteAll':
      memorySecrets.clear();
  }
  return null;
}

void useMemorySecrets() => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .setMockMethodCallHandler(secureStorageChannel, memorySecretsHandler);
