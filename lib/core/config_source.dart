import '../api/api_client.dart';
import 'profile.dart';
import 'profile_store.dart';
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
    final res = await fetchSubscription(profile.subscriptionUrl!);
    final locations = parseSubscription(res.body);
    if (locations.isEmpty) return profile;
    return profile.withBundle(
      locations: locations,
      account: null,
      routing: null,
      dns: subscriptionDns(res.body),
      deviceLimitActive: res.deviceLimitActive,
      deviceLimitReached: res.deviceLimitReached,
      providerInfo: res.info.isEmpty ? null : res.info,
      refreshedAt: DateTime.now(),
    );
  }
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

