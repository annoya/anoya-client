import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class WgKeyPair {
  const WgKeyPair({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;
}

Future<WgKeyPair> generateWgKeyPair() async {
  final algorithm = X25519();
  final pair = await algorithm.newKeyPair();
  final priv = await pair.extractPrivateKeyBytes();
  final pub = (await pair.extractPublicKey()).bytes;
  return WgKeyPair(
    privateKey: base64.encode(priv),
    publicKey: base64.encode(pub),
  );
}

String generateVlessId() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
