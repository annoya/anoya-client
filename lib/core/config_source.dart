import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'amnezia/amnezia_source.dart';
import 'log.dart';
import 'profile.dart';
import 'profile_store.dart';
import 'rule_list_store.dart';
import 'parsers/subscription.dart';
import 'subscription_fetch.dart';

sealed class ConfigSource {
  const ConfigSource(this.profile);

  final Profile profile;

  bool get refreshBeforeConnect => false;

  Future<Profile> refresh() async => profile;

  Future<Profile> resolveSelection(
    String selectionId, {
    bool force = false,
  }) async => profile;

  Future<void> dispose() async {}
}

final class AmneziaConfigSource extends ConfigSource {
  const AmneziaConfigSource(super.profile);

  AmneziaSource get _inner => AmneziaSource(profile);

  @override
  Future<Profile> refresh() => _inner.refresh();

  @override
  Future<Profile> resolveSelection(String selectionId, {bool force = false}) =>
      _inner.resolveSelection(selectionId, force: force);

  @override
  Future<void> dispose() => _inner.dispose();
}

final class SelfhostedSource extends ConfigSource {
  const SelfhostedSource(super.profile);

  @override
  bool get refreshBeforeConnect => true;

  @override
  Future<Profile> refresh() async {
    final token = await ProfileStore.token(profile.id);
    final api = ApiClient(profile.serverUrl!, token: token);
    final cfg = await api.fetchConfig();
    return profile.withBundle(
      locations: cfg.locations,
      account: cfg.account,
      routing: cfg.routing,
      dns: cfg.dns,
      refreshedAt: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() => ProfileStore.deleteToken(profile.id);
}

final class SubscriptionSource extends ConfigSource {
  const SubscriptionSource(super.profile);

  @override
  Future<Profile> refresh() async {
    final probe =
        profile.providerRouting != null || !profile.providerRoutingProbed;
    final info = profile.providerInfo;
    final res = await fetchSubscription(
      profile.subscriptionUrl!,
      probeRouting: probe,
      rendering: profile.rendering,
      probeRenderings: shouldProbeRenderings(profile.rendering),
      fallbackUrl: info?.fallbackUrl ?? '',
      timeout: info?.requestTimeout == null
          ? null
          : Duration(seconds: info!.requestTimeout!),
    );
    var parsed = parseSubscriptionBody(
      res.body,
      source: Uri.parse(profile.subscriptionUrl!).host,
    );
    if (parsed.providers.isNotEmpty) parsed = await withProxyProviders(parsed);
    if (parsed.locations.isEmpty) return profile;
    if (parsed.allPlaceholders && !res.deviceLimitReached) {
      Log.e(
        'subscription refresh ignored',
        '${Uri.parse(profile.subscriptionUrl!).host} sent placeholders only',
      );
      return profile;
    }
    final asked = res.routingProbed || profile.providerRoutingProbed;
    final routing =
        res.routing?.routing ??
        (res.routingProbed ? null : profile.providerRouting);
    final skipped =
        res.routing?.skipped ??
        (res.routingProbed ? 0 : profile.providerRoutingSkipped);
    if (profile.providerRuleListsEnabled && routing != null) {
      await RuleListStore.sync(routing.lists);
    }
    return profile.withBundle(
      locations: parsed.locations,
      account: null,
      routing: null,
      dns: parsed.dns,
      deviceLimitActive: res.deviceLimitActive,
      deviceLimitReached: res.deviceLimitReached,
      unsupportedServers: parsed.unsupported,
      groups: parsed.groups,
      providerRouting: routing,
      providerRoutingSkipped: skipped,
      providerRoutingProbed: asked,
      providerInfo: res.info.isEmpty ? null : res.info,
      usedFallback: res.usedFallback,
      rendering: res.rendering,
      renderingProbed: res.renderingProbed || profile.renderingProbed,
      refreshedAt: DateTime.now(),
    );
  }
}

Future<ParsedSubscription> withProxyProviders(
  ParsedSubscription parsed, {
  http.Client? client,
}) async {
  final locations = [...parsed.locations];
  final unsupported = {...parsed.unsupported};
  for (final provider in parsed.providers) {
    final fetched = await fetchProxyProvider(provider, client: client);
    if (fetched == null) {
      unsupported.update(
        'unreachable list (${provider.name})',
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      continue;
    }
    locations.addAll(fetched.locations);
    fetched.unsupported.forEach(
      (k, v) => unsupported.update(k, (n) => n + v, ifAbsent: () => v),
    );
  }
  return ParsedSubscription(
    locations: locations,
    unsupported: unsupported,
    groups: parsed.groups,
    dns: parsed.dns,
    format: parsed.format,
  );
}

final class LinkSource extends ConfigSource {
  const LinkSource(super.profile);
}

ConfigSource configSourceFor(Profile p) => switch (p.type) {
  ProfileType.selfhosted => SelfhostedSource(p),
  ProfileType.subscription => SubscriptionSource(p),
  ProfileType.amnezia => AmneziaConfigSource(p),
  ProfileType.link => LinkSource(p),
};
