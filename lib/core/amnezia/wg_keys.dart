import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// A WireGuard keypair, in the base64 form every WireGuard tool writes.
class WgKeyPair {
  const WgKeyPair({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;
}

/// Generates the keypair an AWG config is issued against.
///
/// The gateway is told only the public half; the private half never leaves the
/// device and is substituted into the config that comes back. That is the
/// whole reason a fresh pair is generated per request rather than kept: a key
/// the server also knows is not a key.
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

/// The identity a VLESS config is issued against — a uuid the server will
/// accept, and the exact shape Amnezia's client sends (no braces).
String generateVlessId() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 1
  String hex(int from, int to) =>
      b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
