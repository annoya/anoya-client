import '../../l10n/l10n.dart';
import '../app_error.dart';
import '../log.dart';
import '../norm_config.dart';
import '../profile.dart';
import '../profile_store.dart';
import 'amnezia_account.dart';
import 'amnezia_errors.dart';
import 'gateway.dart';
import 'secondary_config.dart';
import 'vpn_key.dart';
import 'wg_keys.dart';

final class AmneziaSource {
  AmneziaSource(this.profile, {AmneziaGateway? gateway}) : _injected = gateway;

  final Profile profile;
  final AmneziaGateway? _injected;

  AmneziaState get _state =>
      profile.amnezia ??
      const AmneziaState(
        serviceType: '',
        serviceProtocol: '',
        userCountryCode: '',
      );

  Future<AmneziaGateway> _gateway() async =>
      _injected ??
      AmneziaGateway(installationUuid: await ProfileStore.amneziaInstallId());

  Future<Profile> refresh() async {
    final key = await ProfileStore.amneziaKey(profile.id);
    if (key == null || key.isEmpty) {
      throw AppErrorException(
        AppError(
          L10n.current.amneziaErrorLostKeyTitle,
          detail: L10n.current.amneziaErrorLostKeyDetail,
        ),
      );
    }
    final gw = await _gateway();
    final res = await gw.accountInfo(
      apiKey: key,
      serviceType: _state.serviceType,
      userCountryCode: _state.userCountryCode,
      subscriptionStatus: _state.account.expired ? 'expired' : 'active',
    );
    if (!res.ok) throw AppErrorException(describeAmneziaError(res));

    final account = AmneziaAccount.fromJson(res.json);
    final next = _state.copyWith(account: account);
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

  Future<Profile> resolveSelection(
    String selectionId, {
    bool force = false,
  }) async {
    final parts = amneziaLocationParts(selectionId);
    if (parts == null) return profile;
    if (!force && _isFresh(selectionId)) return profile;

    final key = await ProfileStore.amneziaKey(profile.id);
    if (key == null || key.isEmpty) return profile;

    final protocol = parts.protocol.isEmpty
        ? _state.serviceProtocol
        : parts.protocol;
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
    if (!res.ok) throw AppErrorException(describeAmneziaError(res));

    final label = _labelFor(selectionId);
    final parsed = parseAmneziaSecondaryConfig(
      res.json,
      label: label,
      privateKey: wg?.privateKey ?? '',
    );
    if (parsed == null) {
      throw AppErrorException(kAmneziaEmptyAnswer);
    }

    Log.i(
      'amnezia: issued ${amneziaProtocolLabel(protocol)} config for '
      '${parts.country.isEmpty ? 'the free service' : parts.country}',
    );

    return profile.copyWith(
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
              id: l.id,
              label: l.label,
              proxy: const {},
              description: l.description,
            ),
      ],
      dns: parsed.dns,
      amnezia: _state.copyWith(
        expiries: {
          if (parsed.expiresAt != null) selectionId: parsed.expiresAt!,
        },
      ),
    );
  }

  bool _isFresh(String selectionId) {
    final current = profile.locations
        .where((l) => l.id == selectionId && !l.isPlaceholder)
        .firstOrNull;
    if (current == null) return false;
    final expiry = _state.expiries[selectionId];
    if (expiry == null) return true;
    return DateTime.now().toUtc().isBefore(
      expiry.subtract(kAmneziaExpiryMargin),
    );
  }

  String _labelFor(String id) {
    for (final l in profile.locations) {
      if (l.id == id) return l.label;
    }
    return profile.name;
  }

  Future<void> dispose() => ProfileStore.deleteAmneziaKey(profile.id);
}

const kAmneziaExpiryMargin = Duration(minutes: 5);

String? amneziaKeyUnsupported(AmneziaVpnKey key) {
  if (key.serviceType == 'amnezia-free') {
    return L10n.current.amneziaErrorFreeTierUnsupported;
  }
  return null;
}

Profile amneziaProfileFor(AmneziaVpnKey key, {required String id}) => Profile(
  id: id,
  type: ProfileType.amnezia,
  name: key.name.isEmpty ? L10n.current.configKindSubscriptionPlain : key.name,
  locations: const [],
  amnezia: AmneziaState(
    serviceType: key.serviceType,
    serviceProtocol: key.serviceProtocol,
    userCountryCode: key.userCountryCode,
  ),
);
