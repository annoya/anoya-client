import '../api/api_client.dart';
import 'log.dart';
import 'profile.dart';
import 'profile_store.dart';
import 'rule_list_store.dart';
import 'parsers/subscription.dart';
import 'subscription_fetch.dart';

/// The provenance of a profile's config — where its locations / account /
/// routing come from and how (if at all) they are re-pulled. One implementation
/// per [ProfileType]; [ProfilesController] orchestrates generically over this,
/// so adding a new kind of source is a new subclass + one `switch` arm, not new
/// branches scattered through the controller.
sealed class ConfigSource {
  const ConfigSource(this.profile);

  final Profile profile;

  /// Whether [ProfilesController.connect] must re-pull before connecting
  /// (server-managed profiles enforce account status / key rotation this way).
  bool get refreshBeforeConnect => false;

  /// Re-pull from the origin. Returns an updated [Profile], or the *same*
  /// instance when this source is static or the pull yielded nothing usable
  /// (the controller treats an identical return as "no change").
  Future<Profile> refresh() async => profile;

  /// Release any resources tied to this profile (e.g. a stored token) when it
  /// is removed. No-op unless overridden.
  Future<void> dispose() async {}
}

/// Self-hosted: an authenticated management server delivers the full bundle.
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

/// Subscription: a URL returning a base64 / Clash list of servers, re-pulled on
/// the poll timer. An empty or failed pull keeps the last good set.
final class SubscriptionSource extends ConfigSource {
  const SubscriptionSource(super.profile);

  @override
  Future<Profile> refresh() async {
    // A panel that was already asked for routing and had none is not asked
    // again on every poll; one that does publish rules is re-read every time,
    // because rules change.
    final probe = profile.providerRouting != null || !profile.providerRoutingProbed;
    // Both come from the last successful answer: a panel's own statement of how
    // long to wait for it and where to ask if it does not answer at all.
    final info = profile.providerInfo;
    final res = await fetchSubscription(
      profile.subscriptionUrl!,
      probeRouting: probe,
      // Asked once per source: either a rendering answered and we go straight
      // to it, or none did and we stop asking.
      rendering: profile.rendering,
      probeRenderings: !profile.renderingProbed,
      fallbackUrl: info?.fallbackUrl ?? '',
      timeout: info?.requestTimeout == null
          ? null
          : Duration(seconds: info!.requestTimeout!),
    );
    var parsed = parseSubscriptionBody(res.body);
    // A Clash document may name its servers elsewhere. Merged before anything
    // else looks at the result, so "how many servers does this subscription
    // have" has one answer.
    if (parsed.providers.isNotEmpty) parsed = await withProxyProviders(parsed);
    if (parsed.locations.isEmpty) return profile;
    // Placeholders replace real servers only when the panel said why (a full
    // device limit — then the entries are its message and the screen explains
    // them). Otherwise the servers we already have are better than text that
    // cannot connect.
    if (parsed.allPlaceholders && !res.deviceLimitReached) {
      Log.e('subscription refresh ignored',
          '${Uri.parse(profile.subscriptionUrl!).host} sent placeholders only');
      return profile;
    }
    // Three outcomes: the panel sent routing, the panel was asked and has none,
    // or we did not ask this time — the last keeps what it told us before,
    // rather than silently dropping its policy.
    final asked = res.routingProbed || profile.providerRoutingProbed;
    final routing = res.routing?.routing ??
        (res.routingProbed ? null : profile.providerRouting);
    final skipped = res.routing?.skipped ??
        (res.routingProbed ? 0 : profile.providerRoutingSkipped);
    // Files first, profile second: the screen reads its status straight from
    // disk, so a list that just arrived must already be there when the new
    // profile appears.
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

/// Fetches every `proxy-providers` list a document points at and folds the
/// servers in.
///
/// A list that cannot be fetched is counted, not silently skipped: the user
/// counted servers in their provider's panel, and a smaller number here with no
/// reason reads as the app losing them.
Future<ParsedSubscription> withProxyProviders(ParsedSubscription parsed) async {
  final locations = [...parsed.locations];
  final unsupported = {...parsed.unsupported};
  for (final provider in parsed.providers) {
    final fetched = await fetchProxyProvider(provider);
    if (fetched == null) {
      unsupported.update('unreachable list (${provider.name})', (n) => n + 1,
          ifAbsent: () => 1);
      continue;
    }
    locations.addAll(fetched.locations);
    fetched.unsupported.forEach((k, v) => unsupported.update(k, (n) => n + v, ifAbsent: () => v));
  }
  return ParsedSubscription(
    locations: locations,
    unsupported: unsupported,
    format: parsed.format,
  );
}

/// Link / imported text: a static snapshot with no origin to re-pull.
final class LinkSource extends ConfigSource {
  const LinkSource(super.profile);
}

ConfigSource configSourceFor(Profile p) => switch (p.type) {
      ProfileType.selfhosted => SelfhostedSource(p),
      ProfileType.subscription => SubscriptionSource(p),
      ProfileType.link => LinkSource(p),
    };

