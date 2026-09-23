import '../api/api_client.dart';
import '../l10n/l10n.dart';
import 'amnezia/amnezia_source.dart';
import 'amnezia/vpn_key.dart';
import 'app_error.dart';
import 'config_source.dart';
import 'oidc_login.dart';
import 'parsers/subscription.dart';
import 'profile.dart';
import 'profile_store.dart';
import 'subscription_fetch.dart';

int _idSeq = 0;

String newProfileId() =>
    'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idSeq++}';

Future<Profile> importSelfhosted(
  String serverUrl,
  String username,
  String password,
) async {
  final api = ApiClient(serverUrl);
  final res = await api.login(username, password);
  api.token = res.token;
  return _selfhostedFromApi(api, res.token);
}

Future<Profile> importSelfhostedOIDC(
  String serverUrl,
  AuthProvider provider,
) async {
  final api = ApiClient(serverUrl);
  final idToken = await obtainOidcIdToken(provider);
  final res = await api.loginOIDC(provider.id, idToken);
  api.token = res.token;
  return _selfhostedFromApi(api, res.token);
}

Future<Profile> _selfhostedFromApi(ApiClient api, String token) async {
  final cfg = await api.fetchConfig();
  final id = newProfileId();
  await ProfileStore.saveToken(id, token);
  final name = cfg.account.displayName.isNotEmpty
      ? cfg.account.displayName
      : Uri.parse(api.baseUrl).host;
  return Profile(
    id: id,
    type: ProfileType.selfhosted,
    name: name,
    locations: cfg.locations,
    serverUrl: api.baseUrl,
    account: cfg.account,
    routing: cfg.routing,
    dns: cfg.dns,
    refreshedAt: DateTime.now(),
  );
}

Future<Profile> importSubscriptionUrl(String name, String url) async {
  final res = await fetchSubscription(url);
  var parsed = parseSubscriptionBody(res.body, source: Uri.parse(url).host);
  if (parsed.providers.isNotEmpty) parsed = await withProxyProviders(parsed);
  final page = res.info.webPageUrl.isNotEmpty ? res.info.webPageUrl : url;
  if (parsed.locations.isEmpty) {
    throw SubscriptionFormatException(_whyNothingUsable(parsed), openUrl: page);
  }
  if (parsed.allPlaceholders && !res.deviceLimitReached) {
    throw SubscriptionFormatException(
      providerMessageInstead(parsed.placeholderLines),
      openUrl: page,
    );
  }
  final title = res.info.title.trim();
  return Profile(
    id: newProfileId(),
    type: ProfileType.subscription,
    name: name.trim().isNotEmpty
        ? name.trim()
        : (title.isNotEmpty ? title : Uri.parse(url).host),
    locations: parsed.locations,
    subscriptionUrl: url,
    dns: parsed.dns,
    deviceLimitActive: res.deviceLimitActive,
    deviceLimitReached: res.deviceLimitReached,
    unsupportedServers: parsed.unsupported,
    groups: parsed.groups,
    rendering: res.rendering,
    renderingProbed: res.renderingProbed,
    providerRouting: res.routing?.routing,
    providerRoutingSkipped: res.routing?.skipped ?? 0,
    providerRoutingProbed: res.routingProbed,
    providerInfo: res.info.isEmpty ? null : res.info,
    refreshedAt: DateTime.now(),
  );
}

AppError _whyNothingUsable(ParsedSubscription parsed) {
  if (parsed.hasUnsupported) {
    return noRunnableServers(parsed.total, parsed.unsupportedList);
  }
  return parsed.format == SubscriptionFormat.unknown
      ? kUnreadableSubscription
      : emptySubscription(parsed.format.label);
}

Future<Profile> importText(String text, {String? name}) async {
  final parsed = parseSubscriptionBody(text, source: name ?? 'pasted text');
  final locations = parsed.locations;
  if (locations.isEmpty) {
    if (parsed.format == SubscriptionFormat.unknown && !text.contains('://')) {
      throw const FormatException(
        'No valid vless://vmess://trojan://ss:// link or subscription found.',
      );
    }
    throw SubscriptionFormatException(_whyNothingUsable(parsed));
  }
  final single = locations.length == 1;
  return Profile(
    id: newProfileId(),
    type: single ? ProfileType.link : ProfileType.subscription,
    name: name?.trim().isNotEmpty == true
        ? name!.trim()
        : (single
              ? locations.first.label
              : L10n.current.importImportedName(locations.length)),
    locations: locations,
    dns: parsed.dns,
    unsupportedServers: parsed.unsupported,
    refreshedAt: DateTime.now(),
  );
}

Future<Profile> importAmneziaKey(String text) async {
  final key = parseAmneziaVpnKey(text);
  if (key == null) {
    throw AppErrorException(
      AppError(
        L10n.current.importNotAKeyTitle,
        detail: L10n.current.importNotAKeyDetail,
      ),
    );
  }
  final refusal = amneziaKeyUnsupported(key);
  if (refusal != null) {
    throw AppErrorException(
      AppError(
        L10n.current.importKeyUnsupportedTitle(key.name),
        detail: refusal,
      ),
    );
  }
  final id = newProfileId();
  await ProfileStore.saveAmneziaKey(id, key.apiKey);
  try {
    return await AmneziaSource(amneziaProfileFor(key, id: id)).refresh();
  } catch (e) {
    await ProfileStore.deleteAmneziaKey(id);
    rethrow;
  }
}
