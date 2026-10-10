import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_prefs.dart';
import 'connection_check.dart';
import 'favorites.dart';
import 'on_demand.dart';
import 'profile.dart';
import 'profile_store.dart';
import 'routing_prefs.dart';
import 'rule_set.dart';

abstract final class CloudStore {
  static const _methods = MethodChannel('vpn/icloud');
  static const _events = EventChannel('vpn/icloud/changes');

  static const quotaViolation = 2;

  static Future<bool> available() async =>
      await _methods.invokeMethod<bool>('available') ?? false;

  static Future<Map<String, String>> snapshot() async =>
      await _methods.invokeMapMethod<String, String>('snapshot') ?? {};

  static Future<void> set(String key, String value) =>
      _methods.invokeMethod('set', {'key': key, 'value': value});

  static Future<void> remove(String key) =>
      _methods.invokeMethod('remove', {'key': key});

  static Stream<int> changes() =>
      _events.receiveBroadcastStream().map((reason) => reason as int);
}

class SyncKey {
  SyncKey._(this._key, this.fingerprint);

  static const _name = 'icloud_sync_key';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(synchronizable: true),
    mOptions: MacOsOptions(synchronizable: true),
  );

  static final _aes = AesGcm.with256bits();

  final SecretKey _key;

  final String fingerprint;

  static Future<SyncKey?> load() async {
    final stored = await _storage.read(key: _name);
    return stored == null ? null : _from(base64Decode(stored));
  }

  static Future<SyncKey> create() async {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    await _storage.write(key: _name, value: base64Encode(bytes));
    return _from(bytes);
  }

  static SyncKey _from(List<int> bytes) => SyncKey._(
    SecretKey(bytes),
    sha256.convert(bytes).toString().substring(0, 16),
  );

  Future<String> seal(String item, String plain) async {
    final box = await _aes.encrypt(
      utf8.encode(plain),
      secretKey: _key,
      aad: utf8.encode(item),
    );
    return base64Encode(box.concatenation());
  }

  Future<String?> open(String item, String sealed) async {
    try {
      final box = SecretBox.fromConcatenation(
        base64Decode(sealed),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      final plain = await _aes.decrypt(
        box,
        secretKey: _key,
        aad: utf8.encode(item),
      );
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }
}

abstract final class SyncItem {
  static const app = 'app';
  static const routing = 'routing';
  static const check = 'check';
  static const onDemand = 'on_demand';
  static const favorites = 'favorites';
  static const keyMarker = 'key';
  static const profilePrefix = 'profile.';
  static const ruleSetPrefix = 'rule_set.';

  static const _singles = {app, routing, check, onDemand, favorites};

  static bool isItem(String key) =>
      _singles.contains(key) ||
      key.startsWith(profilePrefix) ||
      key.startsWith(ruleSetPrefix);
}

Future<Map<String, Object>> localSyncItems() async {
  final onDemand = await OnDemandStore.load();
  return {
    SyncItem.app: (await AppPrefsStore.load()).toJson()..remove('theme_mode'),
    SyncItem.routing: (await RoutingPrefsStore.load()).toJson()
      ..remove('geo_updated_at'),
    SyncItem.check: (await ConnectionCheckStore.load()).toJson(),
    SyncItem.onDemand: {
      'rules': onDemand.rules.map((r) => r.toJson()).toList(),
    },
    SyncItem.favorites: (await FavoritesStore.load()).toJson(),
    for (final s in await RuleSetStore.load())
      '${SyncItem.ruleSetPrefix}${s.id}': s.toJson(),
    for (final p in await ProfileStore.load())
      '${SyncItem.profilePrefix}${p.id}': await profileRecipe(p),
  };
}

const _recipeFields = [
  'id',
  'type',
  'name',
  'server_url',
  'subscription_url',
  'rule_set_id',
  'routing_enabled',
  'provider_routing_enabled',
  'provider_rule_lists_enabled',
  'refresh_hours',
];

const _serverFields = ['locations', 'groups', 'dns', 'unsupported_servers'];

const _amneziaFields = [
  'service_type',
  'service_protocol',
  'user_country_code',
];

const _secretFields = {'token', 'amnezia_key', 'amnezia'};

bool _carriesServers(Object? type, Object? subscriptionUrl) =>
    type == ProfileType.link.name ||
    (type == ProfileType.subscription.name && subscriptionUrl == null);

Future<Map<String, Object?>> profileRecipe(Profile p) async {
  final json = p.toJson();
  final token = p.type == ProfileType.selfhosted
      ? await ProfileStore.token(p.id)
      : null;
  final key = p.type == ProfileType.amnezia
      ? await ProfileStore.amneziaKey(p.id)
      : null;
  final amnezia = json['amnezia'] as Map?;
  final fields = [
    ..._recipeFields,
    if (_carriesServers(json['type'], json['subscription_url']))
      ..._serverFields,
  ];
  return {
    for (final f in fields)
      if (json.containsKey(f)) f: json[f],
    if (amnezia != null)
      'amnezia': {for (final f in _amneziaFields) f: amnezia[f]},
    'token': ?token,
    'amnezia_key': ?key,
  };
}

Profile profileFromRecipe(Map<String, dynamic> recipe, Profile? local) {
  final base = local?.toJson() ?? <String, dynamic>{};
  final fields = [
    ..._recipeFields,
    if (_carriesServers(recipe['type'], recipe['subscription_url']))
      ..._serverFields,
  ];
  for (final f in fields) {
    base.remove(f);
  }
  final amnezia = recipe['amnezia'] as Map?;
  return Profile.fromJson({
    ...base,
    for (final e in recipe.entries)
      if (!_secretFields.contains(e.key)) e.key: e.value,
    if (amnezia != null)
      'amnezia': {
        ...?(base['amnezia'] as Map?)?.cast<String, dynamic>(),
        ...amnezia.cast<String, dynamic>(),
      },
  });
}

String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) => switch (value) {
  Map() => {
    for (final k in value.keys.map((k) => '$k').toList()..sort())
      k: _sorted(value[k]),
  },
  List() => [for (final e in value) _sorted(e)],
  _ => value,
};

String syncDigest(String canonical) =>
    sha256.convert(utf8.encode(canonical)).toString().substring(0, 32);

class SyncPlan {
  final apply = <String, String>{};
  final deleteLocal = <String>{};
  final push = <String, String>{};
  final removeRemote = <String>{};
  final seen = <String, String>{};
}

SyncPlan reconcile({
  required Map<String, String> local,
  required Map<String, String> remote,
  required Set<String> unreadable,
  required Map<String, String> seen,
}) {
  final plan = SyncPlan();
  final keys = {...local.keys, ...remote.keys, ...seen.keys, ...unreadable};
  for (final k in keys) {
    final l = local[k];
    final r = remote[k];
    final s = seen[k];
    final hl = l == null ? null : syncDigest(l);
    final hr = r == null ? null : syncDigest(r);

    if (r != null) {
      if (l == null && s == hr) {
        plan.removeRemote.add(k);
      } else if (hl == hr) {
        plan.seen[k] = hr!;
      } else if (l != null && s == hr) {
        plan.push[k] = l;
        plan.seen[k] = hl!;
      } else {
        plan.apply[k] = r;
        plan.seen[k] = hr!;
      }
    } else if (unreadable.contains(k)) {
      if (l != null) {
        plan.push[k] = l;
        plan.seen[k] = hl!;
      }
    } else if (l != null) {
      if (s == hl) {
        plan.deleteLocal.add(k);
      } else {
        plan.push[k] = l;
        plan.seen[k] = hl!;
      }
    }
  }
  return plan;
}
