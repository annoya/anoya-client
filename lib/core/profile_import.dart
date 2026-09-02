import '../api/api_client.dart';
import 'amnezia/amnezia_source.dart';
import 'amnezia/vpn_key.dart';
import 'app_error.dart';
import 'config_source.dart';
import 'oidc_login.dart';
import 'parsers/subscription.dart';
import 'profile.dart';
import 'profile_store.dart';
import 'subscription_fetch.dart';

/// Turning what the user handed over — a server address and credentials, a
/// subscription URL, pasted text, a `vpn://` key — into a [Profile].
///
/// Each importer fetches, parses and diagnoses; none of them stores the
/// result. [ProfilesController] appends what comes back, so the rules about
/// what counts as a usable configuration live here, next to the parsing, and
/// the controller stays about state.

int _idSeq = 0;

/// A fresh profile id. Unique across a process (the counter) and across
/// launches (the clock).
String newProfileId() =>
    'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_idSeq++}';

/// Self-hosted sign-in with username/password. Fetches the config bundle and
/// stores the session token (Keychain) under the new profile's id.
Future<Profile> importSelfhosted(String serverUrl, String username, String password) async {
  final api = ApiClient(serverUrl);
  final res = await api.login(username, password);
  api.token = res.token;
  return _selfhostedFromApi(api, res.token);
}

/// Self-hosted sign-in via an OIDC provider (SSO).
Future<Profile> importSelfhostedOIDC(String serverUrl, AuthProvider provider) async {
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

/// A subscription by URL (fetched now and on the poll timer).
Future<Profile> importSubscriptionUrl(String name, String url) async {
  final res = await fetchSubscription(url);
  var parsed = parseSubscriptionBody(res.body, source: Uri.parse(url).host);
  if (parsed.providers.isNotEmpty) parsed = await withProxyProviders(parsed);
  final page = res.info.webPageUrl.isNotEmpty ? res.info.webPageUrl : url;
  if (parsed.locations.isEmpty) {
    throw SubscriptionFormatException(_whyNothingUsable(parsed), openUrl: page);
  }
  // Placeholders are servers only when the panel told us why it sent them: a
  // full device limit is a state the app shows and keeps (the entries carry
  // the panel's message). Without that signal they are just text, and adding
  // locations that can never connect would be the app's own invention.
  if (parsed.allPlaceholders && !res.deviceLimitReached) {
    throw SubscriptionFormatException(
      providerMessageInstead(parsed.placeholderLines),
      openUrl: page,
    );
  }
  // The panel's own name for the subscription beats a hostname, and the user's
  // beats both — they typed it on purpose.
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
    // The panel's routing was already fetched with the body; without this it
    // would only appear after the first poll, which reads as the app losing it.
    providerRouting: res.routing?.routing,
    providerRoutingSkipped: res.routing?.skipped ?? 0,
    providerRoutingProbed: res.routingProbed,
    providerInfo: res.info.isEmpty ? null : res.info,
    refreshedAt: DateTime.now(),
  );
}

/// Which of the two "nothing usable" problems this was. They send the user to
/// different places — one to their provider for a different template, the
/// other to a client that speaks the protocols theirs uses.
AppError _whyNothingUsable(ParsedSubscription parsed) {
  if (parsed.hasUnsupported) {
    return noRunnableServers(parsed.total, parsed.unsupportedList);
  }
  // Read it and found nothing, versus could not read it at all: the first is
  // the provider's answer, the second is the format.
  return parsed.format == SubscriptionFormat.unknown
      ? kUnreadableSubscription
      : emptySubscription(parsed.format.label);
}

/// Pasted text or a file's contents: a single share link becomes a `link`
/// profile (no location picker); multiple servers become a static
/// `subscription` snapshot (no refresh URL).
Future<Profile> importText(String text, {String? name}) async {
  final parsed = parseSubscriptionBody(text, source: name ?? 'pasted text');
  final locations = parsed.locations;
  if (locations.isEmpty) {
    // Pasted text that is not a link at all keeps the generic message: at
    // that point "we could not read this format" would be pedantic about
    // something the user can see is a typo.
    if (parsed.format == SubscriptionFormat.unknown && !text.contains('://')) {
      throw const FormatException(
          'No valid vless://vmess://trojan://ss:// link or subscription found.');
    }
    throw SubscriptionFormatException(_whyNothingUsable(parsed));
  }
  final single = locations.length == 1;
  return Profile(
    id: newProfileId(),
    type: single ? ProfileType.link : ProfileType.subscription,
    name: name?.trim().isNotEmpty == true
        ? name!.trim()
        : (single ? locations.first.label : 'Imported (${locations.length})'),
    locations: locations,
    dns: parsed.dns,
    unsupportedServers: parsed.unsupported,
    refreshedAt: DateTime.now(),
  );
}

/// An Amnezia subscription from its `vpn://` key.
///
/// The key alone is not a configuration: it names the subscription and
/// nothing else, so the gateway is asked what it may connect to before the
/// profile is kept. A key the gateway refuses is not added at all — a
/// configuration with no servers and an error where the locations should be
/// is worse than never having accepted it.
Future<Profile> importAmneziaKey(String text) async {
  final key = parseAmneziaVpnKey(text);
  if (key == null) {
    // Not a FormatException: describeError would then talk about share
    // links, and the user typed something that looked like a key.
    throw const AppErrorException(AppError('This isn’t a subscription key',
        detail: 'Expected a vpn:// key from your subscription.'));
  }
  final refusal = amneziaKeyUnsupported(key);
  if (refusal != null) {
    throw AppErrorException(
        AppError('${key.name} isn’t supported here', detail: refusal));
  }
  final id = newProfileId();
  // The credential goes to the keychain first: if the gateway call fails,
  // the orphaned entry is cleaned up below rather than left behind.
  await ProfileStore.saveAmneziaKey(id, key.apiKey);
  try {
    return await AmneziaSource(amneziaProfileFor(key, id: id)).refresh();
  } catch (e) {
    await ProfileStore.deleteAmneziaKey(id);
    rethrow;
  }
}
