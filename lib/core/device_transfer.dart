import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'cloud_sync.dart';
import 'connection_check.dart';
import 'log.dart';
import 'profile_store.dart';
import 'routing_prefs.dart';
import 'rule_set.dart';

const kTransferVersion = 1;
const kTransferPath = '/transfer';
const kTransferMaxBytes = 16 * 1024 * 1024;
const kTransferConnectTimeout = Duration(seconds: 5);
const kTransferResponseTimeout = Duration(seconds: 30);

enum TransferDeviceKind { phone, tv, desktop }

class TransferCode {
  const TransferCode({
    required this.name,
    required this.kind,
    required this.addresses,
    required this.port,
    required this.publicKey,
  });

  final String name;
  final TransferDeviceKind kind;
  final List<String> addresses;
  final int port;
  final List<int> publicKey;

  String toLink() => Uri(
    scheme: 'anoya',
    host: 'receive',
    queryParameters: {
      'v': '$kTransferVersion',
      'n': name,
      't': kind.name,
      'a': addresses.join(','),
      'p': '$port',
      'k': base64Url.encode(publicKey).replaceAll('=', ''),
    },
  ).toString();

  static TransferCode? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'anoya' || uri.host != 'receive') {
      return null;
    }
    final q = uri.queryParameters;
    if (q['v'] != '$kTransferVersion') return null;
    final port = int.tryParse(q['p'] ?? '');
    final addresses = [
      for (final a in (q['a'] ?? '').split(','))
        if (InternetAddress.tryParse(a)?.type == InternetAddressType.IPv4) a,
    ];
    final List<int> key;
    try {
      key = base64Url.decode(base64Url.normalize(q['k'] ?? ''));
    } on FormatException {
      return null;
    }
    if (port == null || port <= 0 || port > 65535) return null;
    if (addresses.isEmpty || key.length != 32) return null;
    return TransferCode(
      name: q['n'] ?? '',
      kind:
          TransferDeviceKind.values.asNameMap()[q['t']] ??
          TransferDeviceKind.phone,
      addresses: addresses,
      port: port,
      publicKey: key,
    );
  }
}

List<String> transferAddresses(Iterable<InternetAddress> addresses) => [
  for (final a in addresses)
    if (a.type == InternetAddressType.IPv4 && _reachableOnLan(a.rawAddress))
      a.address,
];

bool _reachableOnLan(List<int> ip) {
  final [a, b, c, d] = ip;
  if (a == 172 && b == 19 && c == 0 && d < 4) return false;
  return a == 10 || (a == 172 && b >= 16 && b < 32) || (a == 192 && b == 168);
}

Future<List<String>> localTransferAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return transferAddresses(interfaces.expand((i) => i.addresses));
  } catch (e) {
    Log.e('transfer: network interfaces unreadable', '$e');
    return const [];
  }
}

class TransferPackage {
  const TransferPackage({
    required this.from,
    this.profiles = const [],
    this.ruleSets = const [],
    this.routing,
    this.check,
  });

  final String from;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> ruleSets;
  final Map<String, dynamic>? routing;
  final Map<String, dynamic>? check;

  bool get hasSettings => routing != null || check != null;

  Map<String, Object?> toJson() => {
    'v': kTransferVersion,
    'from': from,
    'profiles': profiles,
    'rule_sets': ruleSets,
    'routing': ?routing,
    'check': ?check,
  };

  static TransferPackage fromJson(Map<String, dynamic> j) {
    if (j['v'] != kTransferVersion) {
      throw const FormatException('unknown transfer version');
    }
    List<Map<String, dynamic>> maps(Object? list) => [
      for (final e in (list as List?) ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
    Map<String, dynamic>? map(Object? m) =>
        m is Map ? Map<String, dynamic>.from(m) : null;
    return TransferPackage(
      from: '${j['from'] ?? ''}',
      profiles: [
        for (final p in maps(j['profiles']))
          if (p['id'] is String && p['type'] is String) p,
      ],
      ruleSets: [
        for (final s in maps(j['rule_sets']))
          if (s['id'] is String) s,
      ],
      routing: map(j['routing']),
      check: map(j['check']),
    );
  }
}

Future<TransferPackage> buildTransferPackage({
  required String from,
  required Set<String> profileIds,
  required bool allRuleSets,
  required bool settings,
}) async {
  final profiles = [
    for (final p in await ProfileStore.load())
      if (profileIds.contains(p.id)) await profileRecipe(p),
  ];
  final used = {
    for (final p in profiles) p['rule_set_id'] ?? RuleSet.defaultId,
  };
  return TransferPackage(
    from: from,
    profiles: profiles,
    ruleSets: [
      for (final s in await RuleSetStore.load())
        if (allRuleSets || used.contains(s.id)) s.toJson(),
    ],
    routing: settings
        ? ((await RoutingPrefsStore.load()).toJson()..remove('geo_updated_at'))
        : null,
    check: settings ? (await ConnectionCheckStore.load()).toJson() : null,
  );
}

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
const _info = 'anoya transfer v1';

Future<SecretKey> _boxKey(
  SimpleKeyPair own,
  List<int> theirPublic,
  List<int> senderPublic,
  List<int> receiverPublic,
) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: own,
    remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
  );
  return _hkdf.deriveKey(
    secretKey: shared,
    nonce: [...senderPublic, ...receiverPublic],
    info: utf8.encode(_info),
  );
}

Future<Uint8List> sealTransfer(
  List<int> receiverPublic,
  TransferPackage package,
) async {
  final own = await _x25519.newKeyPair();
  final senderPublic = (await own.extractPublicKey()).bytes;
  final key = await _boxKey(own, receiverPublic, senderPublic, receiverPublic);
  final box = await _aes.encrypt(
    gzip.encode(utf8.encode(jsonEncode(package.toJson()))),
    secretKey: key,
    aad: receiverPublic,
  );
  return Uint8List.fromList([
    kTransferVersion,
    ...senderPublic,
    ...box.concatenation(),
  ]);
}

class TransferKeys {
  TransferKeys._(this._pair, this.publicKey);

  final SimpleKeyPair _pair;
  final List<int> publicKey;

  static Future<TransferKeys> generate() async {
    final pair = await _x25519.newKeyPair();
    return TransferKeys._(pair, (await pair.extractPublicKey()).bytes);
  }

  Future<TransferPackage?> open(List<int> sealed) async {
    if (sealed.length < 1 + 32 + 12 + 16 || sealed[0] != kTransferVersion) {
      return null;
    }
    final senderPublic = sealed.sublist(1, 33);
    try {
      final key = await _boxKey(_pair, senderPublic, senderPublic, publicKey);
      final plain = await _aes.decrypt(
        SecretBox.fromConcatenation(
          sealed.sublist(33),
          nonceLength: _aes.nonceLength,
          macLength: _aes.macAlgorithm.macLength,
        ),
        secretKey: key,
        aad: publicKey,
      );
      final json = jsonDecode(utf8.decode(gzip.decode(plain)));
      return TransferPackage.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      Log.e('transfer: package refused', '$e');
      return null;
    }
  }
}

class TransferReceiver {
  TransferReceiver._(this._server, this._keys, this.code) {
    _server.listen(
      _handle,
      onError: (Object e) {
        Log.e('transfer: receiver failed', '$e');
      },
    );
  }

  final HttpServer _server;
  final TransferKeys _keys;
  final TransferCode code;
  final _received = Completer<TransferPackage>();
  bool _closed = false;

  Future<TransferPackage> get received => _received.future;

  static Future<TransferReceiver> start({
    required String name,
    required TransferDeviceKind kind,
    required List<String> addresses,
  }) async {
    final keys = await TransferKeys.generate();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    return TransferReceiver._(
      server,
      keys,
      TransferCode(
        name: name,
        kind: kind,
        addresses: addresses,
        port: server.port,
        publicKey: keys.publicKey,
      ),
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'POST' || request.uri.path != kTransferPath) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (_received.isCompleted) {
        response.statusCode = HttpStatus.gone;
        return;
      }
      final body = BytesBuilder(copy: false);
      await for (final chunk in request) {
        body.add(chunk);
        if (body.length > kTransferMaxBytes) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
      }
      final package = await _keys.open(body.takeBytes());
      if (package == null || _received.isCompleted) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      _received.complete(package);
      response.statusCode = HttpStatus.ok;
    } catch (e) {
      Log.e('transfer: request failed', '$e');
      response.statusCode = HttpStatus.badRequest;
    } finally {
      await response.close();
      if (_received.isCompleted) unawaited(close());
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server.close(force: true);
  }
}

enum TransferFailure { unreachable, refused }

class TransferException implements Exception {
  const TransferException(this.failure);

  final TransferFailure failure;

  @override
  String toString() => 'TransferException(${failure.name})';
}

Future<void> sendTransfer(TransferCode code, Uint8List sealed) async {
  final client = HttpClient()..connectionTimeout = kTransferConnectTimeout;
  final done = Completer<void>();
  var pending = code.addresses.length;
  var refused = false;

  Future<void> attempt(String address) async {
    try {
      final request = await client.post(address, code.port, kTransferPath);
      request.headers.contentType = ContentType.binary;
      request.contentLength = sealed.length;
      request.add(sealed);
      final response = await request.close().timeout(kTransferResponseTimeout);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.ok) {
        if (!done.isCompleted) done.complete();
        return;
      }
      if (response.statusCode == HttpStatus.forbidden ||
          response.statusCode == HttpStatus.gone) {
        refused = true;
      }
    } catch (e) {
      Log.e('transfer: $address unreachable', '$e');
    } finally {
      pending--;
      if (pending == 0 && !done.isCompleted) {
        done.completeError(
          TransferException(
            refused ? TransferFailure.refused : TransferFailure.unreachable,
          ),
        );
      }
    }
  }

  for (final a in code.addresses) {
    unawaited(attempt(a));
  }
  try {
    await done.future;
  } finally {
    client.close(force: true);
  }
}
