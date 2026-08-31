import '../app_error.dart';
import '../log.dart';
import '../norm_config.dart';
import '../profile.dart';
import '../profile_store.dart';
import 'agw_ffi.dart';
import 'amnezia_account.dart';
import 'amnezia_errors.dart';
import 'gateway.dart';
import 'secondary_config.dart';
import 'vpn_key.dart';
import 'wg_keys.dart';

/// An Amnezia Premium/Free subscription.
///
/// It differs from every other source in when the servers exist. A panel
/// publishes its list and the app reads it; Amnezia publishes only a list of
/// *places*, and issues the actual server — keys and all — one at a time, when
/// asked. So a refresh here answers "what may I connect to", and the settings
/// for the one the user picked are fetched separately, just before they are
/// needed.
///
/// Both halves live here rather than in the controller: the point of this
/// class is that the rest of the app never learns Amnezia exists.
final class AmneziaSource {
  AmneziaSource(this.profile, {AmneziaGateway? gateway}) : _injected = gateway;

  final Profile profile;
  final AmneziaGateway? _injected;

  AmneziaState get _state =>
      profile.amnezia ??
      const AmneziaState(serviceType: '', serviceProtocol: '', userCountryCode: '');

  Future<AmneziaGateway> _gateway() async =>
      _injected ??
      AmneziaGateway(installationUuid: await ProfileStore.amneziaInstallId());

  /// Re-reads what the subscription is allowed to do.
  ///
  /// Called on the refresh the user asks for and on the poll timer, never on
  /// every screen that shows it: the answer changes on the scale of a
  /// subscription, and asking on each visit would spend the user's traffic to
  /// learn what we already knew.
  Future<Profile> refresh() async {
    final key = await ProfileStore.amneziaKey(profile.id);
    if (key == null || key.isEmpty) {
      throw const AppErrorException(AppError('This subscription lost its key',
          detail: 'Remove the configuration and add it again.'));
    }
    final gw = await _gateway();
    final res = await gw.accountInfo(
      apiKey: key,
      serviceType: _state.serviceType,
      userCountryCode: _state.userCountryCode,
      subscriptionStatus: _state.account.expired ? 'expired' : 'active',
    );
    if (!res.ok) throw AppErrorException(describeAmneziaError(res.code, detail: _hint(res)));

    final account = AmneziaAccount.fromJson(res.json);
    final next = _state.copyWith(account: account);
    // Locations are rebuilt from what the gateway now offers, but a config
    // already issued for a place that is still on the list keeps its settings:
    // re-issuing one costs a round trip and a device slot, and nothing about
    // the account answer invalidates it.
    final resolved = {
      for (final l in profile.locations)
        if (l.proxy.isNotEmpty) l.id: l,
    };
    final locations = [
      for (final l in amneziaLocations(next)) resolved[l.id] ?? l,
    ];
    return profile.copyWith(
      locations: locations,
      amnezia: next,
      refreshedAt: DateTime.now(),
    );
  }

  /// Issues (or re-issues) the settings for one place, if they are missing or
  /// stale.
  ///
  /// The gateway states how long a config is good for, and running an expired
  /// one fails a handshake with nothing to explain it — so the expiry is
  /// checked here, before the engine ever sees it, which is the only place
  /// that can tell the difference between "expired" and "broken".
  Future<Profile> resolveSelection(String selectionId, {bool force = false}) async {
    final parts = amneziaLocationParts(selectionId);
    if (parts == null) return profile;
    if (!force && _isFresh(selectionId)) return profile;

    final key = await ProfileStore.amneziaKey(profile.id);
    if (key == null || key.isEmpty) return profile;

    final protocol = parts.protocol.isEmpty ? _state.serviceProtocol : parts.protocol;
    // AWG is issued against a key this device makes: the gateway is told the
    // public half and never sees the private one.
    final wg = protocol == 'awg' ? await generateWgKeyPair() : null;
    final publicKey = wg?.publicKey ?? generateVlessId();

    final gw = await _gateway();
    final res = await gw.config(
      apiKey: key,
      serviceType: _state.serviceType,
      serviceProtocol: protocol,
      userCountryCode: _state.userCountryCode,
      publicKey: publicKey,
      serverCountryCode: parts.country,
      isConnectEvent: true,
    );
    if (!res.ok) throw AppErrorException(describeAmneziaError(res.code, detail: _hint(res)));

    final label = _labelFor(selectionId);
    final parsed = parseAmneziaSecondaryConfig(res.json,
        label: label, privateKey: wg?.privateKey ?? '');
    if (parsed == null) {
      throw AppErrorException(describeAmneziaError(AgwStatus.emptyConfig));
    }

    Log.i('amnezia: issued ${amneziaProtocolLabel(protocol)} config for '
        '${parts.country.isEmpty ? 'the free service' : parts.country}');

    return profile.copyWith(
      // Only the place being connected through keeps a server. The others go
      // back to being names: a config we are not using is one the gateway may
      // have rotated off the account already, and keeping it would mean
      // handing the engine credentials the server has forgotten — which fails
      // as silence, because that is what WireGuard does with a peer it does
      // not know.
      locations: [
        for (final l in profile.locations)
          if (l.id == selectionId)
            Location(
              id: l.id,
              label: l.label,
              proxy: parsed.location.proxy,
              description: l.description,
            )
          else if (l.isPlaceholder)
            l
          else
            Location(
                id: l.id, label: l.label, proxy: const {}, description: l.description),
      ],
      // The resolvers the config came with. They are the server's own, often
      // reachable only through the tunnel, and substituting ours would send
      // every query somewhere the subscription did not choose (ADR-008).
      dns: parsed.dns,
      // One selection, one expiry: the others no longer have a server for a
      // date to belong to.
      amnezia: _state.copyWith(expiries: {
        if (parsed.expiresAt != null) selectionId: parsed.expiresAt!,
      }),
    );
  }

  /// Whether the config in hand can still be used.
  ///
  /// Only the selected server is ever held, and only until the expiry the
  /// gateway stated, minus a margin — a config that runs out while the tunnel
  /// is coming up fails in the least explicable way there is. An unresolved
  /// location is never fresh; a dateless one is trusted until the selection
  /// changes, which is the point at which it is replaced anyway.
  bool _isFresh(String selectionId) {
    final current = profile.locations
        .where((l) => l.id == selectionId && !l.isPlaceholder)
        .firstOrNull;
    if (current == null) return false;
    final expiry = _state.expiries[selectionId];
    if (expiry == null) return true;
    return DateTime.now().toUtc().isBefore(expiry.subtract(kAmneziaExpiryMargin));
  }

  String _labelFor(String id) {
    for (final l in profile.locations) {
      if (l.id == id) return l.label;
    }
    return profile.name;
  }

  /// The gateway's own sentence, when it sent one worth repeating. Their
  /// wording is often more specific than any code-to-text table.
  String _hint(AgwResponse res) {
    try {
      final message = res.json['message'];
      return message is String ? message : '';
    } catch (_) {
      return '';
    }
  }

  Future<void> dispose() => ProfileStore.deleteAmneziaKey(profile.id);
}

/// How early a dated config is replaced. Enough to cover a slow gateway and a
/// slow handshake, so the tunnel never comes up on a key that expires between
/// the request and the first packet.
const kAmneziaExpiryMargin = Duration(minutes: 5);

/// Why a key cannot be used here, or null when it can.
///
/// The free tier is refused, and refused *here* rather than by failing later:
/// the gateway asks for a CAPTCHA before it will issue a free configuration,
/// and this app has no way to show one. A key that imports cleanly and then
/// never connects would read as a broken app; a refusal that says why sends
/// the user somewhere that works.
String? amneziaKeyUnsupported(AmneziaVpnKey key) {
  if (key.serviceType == 'amnezia-free') {
    return 'This subscription is free-tier, and its gateway asks for a CAPTCHA '
        'before it issues a configuration — which this app cannot show. Use '
        'the app it came from, or add a paid key here.';
  }
  return null;
}

/// Builds the configuration a freshly imported key stands for. The gateway is
/// not called here — [AmneziaSource.refresh] does that, and doing it in one
/// place means an import and a later refresh cannot disagree.
Profile amneziaProfileFor(AmneziaVpnKey key, {required String id}) => Profile(
      id: id,
      type: ProfileType.amnezia,
      // Whatever the key calls itself. The same format and the same gateway
      // serve providers other than Amnezia, so nothing here may assume one.
      name: key.name.isEmpty ? 'Subscription' : key.name,
      locations: const [],
      amnezia: AmneziaState(
        serviceType: key.serviceType,
        serviceProtocol: key.serviceProtocol,
        userCountryCode: key.userCountryCode,
      ),
    );
