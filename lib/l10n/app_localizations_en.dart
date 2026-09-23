// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VPN';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonConnect => 'Connect';

  @override
  String get commonDisconnect => 'Disconnect';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonName => 'Name';

  @override
  String get commonAll => 'ALL';

  @override
  String get commonFavorites => 'FAVORITES';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonJustNow => 'just now';

  @override
  String get settingsSectionConfigurations => 'CONFIGURATIONS';

  @override
  String get settingsSectionConnection => 'CONNECTION';

  @override
  String get settingsSectionRouting => 'ROUTING';

  @override
  String get settingsSectionGeneral => 'GENERAL';

  @override
  String get settingsSectionDiagnostics => 'DIAGNOSTICS';

  @override
  String get settingsSectionAbout => 'ABOUT';

  @override
  String get settingsConfigurations => 'Configurations';

  @override
  String settingsConfigurationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count configurations',
      one: '1 configuration',
    );
    return '$_temp0';
  }

  @override
  String get uiNounConfiguration => 'configuration';

  @override
  String get settingsAutoConnect => 'Auto-connect';

  @override
  String get settingsAutoConnectSubtitle => 'Connect when Windows starts';

  @override
  String get onDemandTitle => 'On demand';

  @override
  String get settingsDisconnectOnSleep => 'Disconnect on sleep';

  @override
  String get settingsDisconnectOnSleepSubtitle =>
      'Drop the tunnel when the device sleeps';

  @override
  String get settingsAlwaysOnSubtitle =>
      'A system switch — set in Android settings';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsConnectionCheckOn => 'Connection check · on';

  @override
  String get settingsConnectionCheckOff => 'Connection check · off';

  @override
  String get settingsLanDirect => 'Local network direct';

  @override
  String get settingsLanDirectSubtitle => 'LAN traffic bypasses the VPN';

  @override
  String get ruleSetsTitle => 'Rule sets';

  @override
  String settingsRuleSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get settingsDefaultDns => 'Default DNS';

  @override
  String settingsDefaultDnsSubtitle(String name) {
    return '$name · used when a configuration brings none';
  }

  @override
  String get settingsDnsCustom => 'Custom…';

  @override
  String get settingsDnsCustomSubtitle => 'any address the engine accepts';

  @override
  String get settingsDnsResolverLabel => 'Resolver';

  @override
  String get settingsDnsUseCloudflare => 'Use Cloudflare';

  @override
  String settingsGeoDownloaded(String size) {
    return 'downloaded · $size';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystemSubtitle => 'Follow the device setting';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutEngine => 'Engine';

  @override
  String get aboutVersionCopied => 'Version copied';

  @override
  String get aboutTermsOfService => 'Terms of Service';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutNotPublishedYet => 'Not published yet';

  @override
  String get uiCouldNotOpenPage => 'Couldn’t open that page.';

  @override
  String get advancedSectionConnectionCheck => 'CONNECTION CHECK';

  @override
  String get advancedSectionLastCheck => 'LAST CHECK';

  @override
  String get advancedCheckAfterConnecting => 'Check after connecting';

  @override
  String get advancedCheckAfterConnectingSubtitle =>
      'Fetch a page through the server and time the answer';

  @override
  String get advancedTestUrl => 'Test URL';

  @override
  String get advancedUrlLabel => 'URL';

  @override
  String get advancedUseDefault => 'Use the default';

  @override
  String get advancedInvalidUrl => 'Enter an http:// or https:// address.';

  @override
  String get advancedGiveUpAfter => 'Give up after';

  @override
  String advancedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get advancedTestNow => 'Test now';

  @override
  String get advancedNeedsTunnelNote =>
      'The request goes through the running engine, so the tunnel has to be up to test it.';

  @override
  String get advancedCheckScopeNote =>
      'The request goes through the server itself, so routing rules do not affect it. It proves the server passes traffic — not that your traffic goes through it.';

  @override
  String get advancedNoAnswer => 'No answer';

  @override
  String advancedNoAnswerDetail(String failure) {
    return '$failure The tunnel is up, so this is the server or the network beyond it.';
  }

  @override
  String get advancedTrafficGettingThrough => 'Traffic is getting through';

  @override
  String advancedAnsweredIn(int ms) {
    return 'Answered in $ms ms';
  }

  @override
  String advancedResultVia(String ago, String via) {
    return '$ago · through $via';
  }

  @override
  String commonMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String advancedHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String get alwaysOnTitle => 'Always-on VPN';

  @override
  String get alwaysOnStartedBySystem => 'Started by the system';

  @override
  String get alwaysOnStartedBySystemSubtitle =>
      'At boot, and again whenever the tunnel drops';

  @override
  String get alwaysOnBlockWithoutVpn => 'Block connections without VPN';

  @override
  String get alwaysOnBlockWithoutVpnSubtitle =>
      'The system’s kill switch, on the same screen';

  @override
  String get alwaysOnNote =>
      'Android owns this switch, so it lives in system settings: Network & internet → VPN → the gear next to this app. The system starts whatever configuration was used last.';

  @override
  String get alwaysOnOpenSystemSettings => 'Open system VPN settings';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get dnsSectionInEffect => 'IN EFFECT';

  @override
  String get dnsSectionDropped => 'DROPPED';

  @override
  String get dnsParallelNote =>
      'Asked at the same time; the first answer wins.';

  @override
  String get dnsFallbackNote =>
      'This configuration names no resolver of its own, so the app uses its default — change it in Settings › Default DNS.';

  @override
  String get dnsProviderNote =>
      'Chosen by whoever set up this configuration, and it changes with it.';

  @override
  String get dnsProxyResolvedDirectlyNote =>
      'The address of the server you connect through is always resolved directly. It has to be — nothing could reach the tunnel otherwise.';

  @override
  String dnsResolverSubtitle(String protocol, String origin) {
    return '$protocol · $origin';
  }

  @override
  String get dnsPinIgnoredTooltip =>
      'This configuration asked for an outbound this app does not create, so the request was dropped and the resolver is reached directly.';

  @override
  String get dnsOriginAppDefault => 'app default';

  @override
  String get dnsOriginSubscription => 'from your subscription';

  @override
  String get dnsOriginOrganisation => 'from your organisation';

  @override
  String get dnsOriginConfiguration => 'from this configuration';

  @override
  String get dnsRoutingDirect => 'direct';

  @override
  String get dnsRoutingFollowsRules => 'follows your rules';

  @override
  String get dnsRoutingThroughTunnel => 'through the tunnel';

  @override
  String get dnsProtocolDoh => 'DNS over HTTPS';

  @override
  String get dnsProtocolDot => 'DNS over TLS';

  @override
  String get dnsProtocolDoq => 'DNS over QUIC';

  @override
  String get dnsProtocolPlain => 'Plain, unencrypted';

  @override
  String get dnsDropMalformed =>
      'Not a resolver address. Nothing from a subscription is put into the engine configuration unchecked.';

  @override
  String get dnsDropUnknownScheme =>
      'The engine has no scheme for this. Keeping it would have failed the whole configuration, not just this line.';

  @override
  String get dnsDropCannotCarry =>
      'Plain DNS cannot travel through this server, and sending it outside the tunnel would show every site you visit to your network.';

  @override
  String dnsDropTooMany(int max) {
    return 'Past the $max the engine is given. It asks them all at once, so a longer list costs time without answering better.';
  }

  @override
  String get dnsPresetQuad9Note => 'filters known-malicious domains';

  @override
  String get dnsPresetAdGuardNote => 'filters ads and trackers';

  @override
  String get dnsErrorNotResolverAddress => 'Not a resolver address.';

  @override
  String get dnsErrorAddressedByName =>
      'Addressed by name, so it would need resolving before it could resolve anything. Use its IP address.';

  @override
  String get geoTitle => 'GeoIP & GeoSite';

  @override
  String get geoSectionDatabases => 'DATABASES';

  @override
  String get geoSectionUpdates => 'UPDATES';

  @override
  String get geoGeoipSource => 'GeoIP source';

  @override
  String get geoGeositeSource => 'GeoSite source';

  @override
  String get geoDownloadUrlLabel => 'Download URL';

  @override
  String get geoResetToDefault => 'Reset to default';

  @override
  String get geoNotDownloaded => 'not downloaded';

  @override
  String get geoNever => 'never';

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get geoLastUpdated => 'Last updated';

  @override
  String get geoAutoUpdate => 'Auto-update';

  @override
  String get geoAutoUpdateSubtitle => 'Weekly, when already downloaded';

  @override
  String get geoUpdateNow => 'Update now';

  @override
  String get geoDownload => 'Download (~25 MB)';

  @override
  String get geoDatabaseHostSubject => 'the database host';

  @override
  String get geositeCategoryLabel => 'Category';

  @override
  String geositeDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count domains',
      one: '1 domain',
    );
    return '$_temp0';
  }

  @override
  String get geositeNoCategories =>
      'No categories — download the geo databases first.';

  @override
  String uiNothingMatches(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String get geositeSectionPopular => 'POPULAR';

  @override
  String geositeSectionAll(int count) {
    return 'ALL · $count';
  }

  @override
  String geositeSectionAllMatch(int count, int total) {
    return 'ALL · $count OF $total MATCH';
  }

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsSectionCollection => 'COLLECTION';

  @override
  String get logsSectionTunnel => 'TUNNEL';

  @override
  String get logsSectionApp => 'APP';

  @override
  String get logsCollect => 'Collect logs';

  @override
  String get logsCollectSubtitle =>
      'Off: the app, the tunnel and the core stop writing. Existing files stay readable.';

  @override
  String get logsTunnel => 'Tunnel';

  @override
  String get logsTunnelSubtitle => 'Network Extension events';

  @override
  String get logsCore => 'Core (mihomo)';

  @override
  String get logsCoreSubtitle => 'Engine log: dials, DNS, routing';

  @override
  String get logsApplication => 'Application';

  @override
  String get logsApplicationSubtitle => 'Client-side events';

  @override
  String get logsSaveAllZip => 'Save all logs (.zip)';

  @override
  String get logsSaveAll => 'Save all logs';

  @override
  String get logsSaveToFile => 'Save to file…';

  @override
  String get logsSaveToFileSubtitle => 'Pick a folder on this device';

  @override
  String get logsShare => 'Share…';

  @override
  String get logsShareSubtitle => 'Send the archive somewhere';

  @override
  String get logsSaveDialogTitle => 'Save logs';

  @override
  String logsSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get logsClearAll => 'Clear all logs';

  @override
  String get logsClearAllQuestion => 'Clear all logs?';

  @override
  String get logsClearAllContent =>
      'The app, tunnel and core logs will be deleted from this device. The tunnel and core logs can only be cleared while the VPN is connected.';

  @override
  String get logsCleared => 'Logs cleared.';

  @override
  String get logsAppLogClearedOnly =>
      'App log cleared. The tunnel and core logs need the VPN connected.';

  @override
  String get logsNoLog => 'No log.';

  @override
  String get logsNoLogYet => 'No log yet.';

  @override
  String get logsEmpty => 'Empty';

  @override
  String get logsUnavailable =>
      'Logs are available only while the tunnel is running.\n(The tunnel process keeps its logs on its own side and streams them to the app over IPC.)';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String configKindSelfhosted(String servers) {
    return 'Self-hosted · $servers';
  }

  @override
  String configKindSubscription(String servers, String groups) {
    return 'Subscription · $servers$groups';
  }

  @override
  String get configKindSubscriptionPlain => 'Subscription';

  @override
  String get configKindSingleServer => 'Single server';

  @override
  String commonServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String configServersOfOffered(int ours, int offered) {
    String _temp0 = intl.Intl.pluralLogic(
      offered,
      locale: localeName,
      other: '$ours of $offered servers',
      one: '$ours of 1 server',
    );
    return '$_temp0';
  }

  @override
  String configGroupsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count groups',
      one: ' · 1 group',
    );
    return '$_temp0';
  }

  @override
  String get configSource => 'Source';

  @override
  String get configSourceViaFallback =>
      'Last refresh used the subscription’s backup address';

  @override
  String get configCouldNotOpenLink => 'Couldn’t open that link.';

  @override
  String get configLinkCopied => 'Link copied';

  @override
  String configUnsupportedTitle(int skipped, int offered) {
    return '$skipped of $offered servers unsupported';
  }

  @override
  String configUnsupportedDetail(String kinds, int available) {
    return 'They use $kinds, which this app cannot run yet. The other $available are available.';
  }

  @override
  String get configSetActive => 'Set active';

  @override
  String get configRemoveConfiguration => 'Remove configuration';

  @override
  String configRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get configRemoveDetail =>
      'This configuration will be removed from this device.';

  @override
  String get configSectionSubscription => 'SUBSCRIPTION';

  @override
  String get configRanUntil => 'Ran until';

  @override
  String get configRunsUntil => 'Runs until';

  @override
  String get configDevices => 'Devices';

  @override
  String configDevicesUsed(int active, int max) {
    return '$active of $max used';
  }

  @override
  String configDateLong(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMMM y',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String configDateShort(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'd MMM y',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String configDaysLeft(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$date · $_temp0';
  }

  @override
  String get accountExpiredTitle => 'Subscription expired';

  @override
  String get configSubscriptionExpiredDetail =>
      'Renew the subscription, then refresh this configuration.';

  @override
  String get configSectionThisDevice => 'THIS DEVICE';

  @override
  String get configDeviceIdentifiedSubtitle =>
      'Identified to your subscription, which counts devices';

  @override
  String get configDeviceId => 'Device id';

  @override
  String get configDeviceHintAmnezia =>
      'Your subscription counts devices by this id. It is made once and kept, so reconnecting costs no slot — but a reinstall takes a new one.';

  @override
  String get configDeviceHintPanel =>
      'Your subscription counts devices by an id this app generates once and keeps. Reinstalling makes a new one, which takes another slot.';

  @override
  String configCopiedTitle(String title) {
    return '$title copied';
  }

  @override
  String configDnsSummary(String host, String routing) {
    return '$host · $routing';
  }

  @override
  String configDnsMore(int count) {
    return ' · +$count more';
  }

  @override
  String configDnsDropped(int count) {
    return '$count dropped';
  }

  @override
  String get configDnsByApp => 'DNS by the app';

  @override
  String configDnsOrigin(String origin) {
    return 'DNS $origin';
  }

  @override
  String configDnsRefused(int count) {
    return 'DNS: $count refused';
  }

  @override
  String get configRouting => 'Routing';

  @override
  String get configRuleSet => 'Rule set';

  @override
  String get configRuleSetDefault => 'Default';

  @override
  String get configRuleLists => 'Rule lists';

  @override
  String get ruleSetModeSplit => 'Split';

  @override
  String get ruleSetModeFull => 'Full tunnel';

  @override
  String ruleSetSummary(String mode, String rules) {
    return '$mode · $rules';
  }

  @override
  String get ruleSetNoRules => 'no rules';

  @override
  String get configNoExceptions => 'no exceptions';

  @override
  String configRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String configSkippedNotSupported(int count) {
    return '$count not supported';
  }

  @override
  String configListsUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists unavailable',
      one: '1 list unavailable',
    );
    return '$_temp0';
  }

  @override
  String configRulesNeedLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need their lists',
      one: '1 needs their lists',
    );
    return '$_temp0';
  }

  @override
  String configDownloadingLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count lists…',
      one: 'Downloading one list…',
    );
    return '$_temp0';
  }

  @override
  String configRuleListsOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules need them',
      one: '1 rule needs them',
    );
    return 'Off · $_temp0';
  }

  @override
  String get configChecking => 'Checking…';

  @override
  String get configNoneDownloadedYet => 'None downloaded yet';

  @override
  String configListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String configListsDownloadedOf(int have, int total) {
    return '$have of $total downloaded';
  }

  @override
  String configListsSize(String count, int kb) {
    return '$count · $kb KB';
  }

  @override
  String configListsFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists could not be downloaded',
      one: 'One list could not be downloaded',
    );
    return '$_temp0';
  }

  @override
  String configListsFailedDetail(int count, String names, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names from $hosts — the rules using them are not applied.',
      one: '$names from $hosts — the rule using it is not applied.',
    );
    return '$_temp0';
  }

  @override
  String configReplacedBy(String name) {
    return 'Replaced by $name';
  }

  @override
  String get configRoutingOffSummary => 'Off · everything through the VPN';

  @override
  String get configManagedByOrganization => 'Managed by your organization';

  @override
  String configManagedSummary(String mode, int count) {
    return '$mode · $count rules, set on the server';
  }

  @override
  String configSetByOrganization(String mode) {
    return '$mode · set by your organization';
  }

  @override
  String get configSectionOrganizationRouting => 'ORGANIZATION ROUTING';

  @override
  String get configSectionSubscriptionRouting => 'SUBSCRIPTION ROUTING';

  @override
  String get configSectionDeviceRouting => 'DEVICE ROUTING';

  @override
  String get configOrganizationRoutingNote =>
      'Your organization sets this policy and applies it. You can see what it is; changing it is done on their side.';

  @override
  String get configSubscriptionRoutes => 'the subscription’s routes';

  @override
  String get configSubscriptionRoutingNote =>
      'Turn the switch off to use your own rule set instead. Your subscription cannot enforce this either way.';

  @override
  String get configDeviceRoutingNote =>
      'Rule sets are shared by every configuration; the switch is per configuration, so a work subscription and a personal one can use the same set differently.';

  @override
  String get configSectionDetails => 'DETAILS';

  @override
  String get configGetSupport => 'Get support';

  @override
  String get configNoPlanDetails =>
      'Your subscription reported no plan details.';

  @override
  String configUsedNoLimit(String used) {
    return 'Used $used · no limit';
  }

  @override
  String configTrafficOf(String used, String total) {
    return 'Traffic: $used of $total';
  }

  @override
  String get configNoExpiryDate => 'No expiry date given';

  @override
  String configExpiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String configActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String configPlanLine(String when) {
    return '$when · what the subscription reports, not verified here';
  }

  @override
  String get configAccount => 'Account';

  @override
  String configStatus(String status) {
    return 'Status: $status';
  }

  @override
  String configStatusOnHold(String status) {
    return 'Status: $status · starts on first use';
  }

  @override
  String configStatusExpires(String status, String date) {
    return 'Status: $status · expires $date';
  }

  @override
  String get configLastRefreshed => 'Last refreshed';

  @override
  String get configRefreshEvery => 'Refresh every';

  @override
  String get configHours => 'Hours';

  @override
  String get configRefreshAsSubscriptionAsks => 'As the subscription asks';

  @override
  String get configRefreshEnterWholeHours => 'Enter a whole number of hours.';

  @override
  String configRefreshNever(String every) {
    return 'never · $every';
  }

  @override
  String configRefreshAgo(String ago, String every) {
    return '$ago · $every';
  }

  @override
  String configAutoEveryMinutes(int count) {
    return 'auto every $count min';
  }

  @override
  String configAutoEveryHours(int count) {
    return 'auto every $count h';
  }

  @override
  String configAutoEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'auto every $count days',
      one: 'auto every day',
    );
    return '$_temp0';
  }

  @override
  String get configRefreshNow => 'Refresh now';

  @override
  String configRefreshFailed(String detail) {
    return 'Couldn’t refresh — $detail';
  }

  @override
  String get configRefreshFailedFallback =>
      'showing the servers we already have.';

  @override
  String get configOrganizationPolicyDetail =>
      'These rules are set on the server and cannot be changed here.';

  @override
  String configSentBy(String name) {
    return 'Sent by $name';
  }

  @override
  String get configProviderPolicyDetail =>
      'Read-only. Refreshing the subscription replaces them.';

  @override
  String configProviderPolicyDetailSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count more rules could not be translated for this app and are not applied.',
      one:
          '1 more rule could not be translated for this app and is not applied.',
    );
    return 'Read-only. Refreshing the subscription replaces them. $_temp0';
  }

  @override
  String get ruleSetSplitTunneling => 'Split tunneling';

  @override
  String get ruleSetGeoNotDownloaded => 'Geo databases not downloaded';

  @override
  String get ruleSetGeoNotDownloadedDetail =>
      'geoip / geosite rules are inactive until then (~25 MB)';

  @override
  String get ruleSetRulesHeader => 'RULES — FIRST MATCH WINS';

  @override
  String get homeAddConfiguration => 'Add configuration';

  @override
  String get homeConfigurationSettings => 'Configuration settings';

  @override
  String homeChipAuto(String state) {
    return 'Auto · $state';
  }

  @override
  String homeChipRouting(String state) {
    return 'Routing · $state';
  }

  @override
  String homeChipLogs(String state) {
    return 'Logs · $state';
  }

  @override
  String get homeStateOn => 'on';

  @override
  String get homeStateOff => 'off';

  @override
  String get homeAutoPaused => 'paused';

  @override
  String get homeAutoNotArmed => 'not armed';

  @override
  String get homeCheckFailedTitle => 'Connected, but nothing came back';

  @override
  String get homeCheckFailedDetail =>
      'The check found no answer through this server. Try another one, or open Advanced.';

  @override
  String get homeAutoConnectPausedTitle => 'Auto-connect paused';

  @override
  String get homeAutoConnectPausedDetail => 'Press Connect to arm it again';

  @override
  String get homeAutoConnectNotArmedTitle => 'Auto-connect not armed yet';

  @override
  String get homeAutoConnectNotArmedDetail =>
      'Connect once so the system can take over';

  @override
  String get homeNoServers => 'No servers';

  @override
  String get homeGroupAuto => 'auto';

  @override
  String homeGroupAutoPicked(String server) {
    return 'auto · $server';
  }

  @override
  String homeAccountUntil(String status, String until) {
    return '$status · until $until';
  }

  @override
  String get homeConfiguration => 'Configuration';

  @override
  String get homeServer => 'Server';

  @override
  String get homeChosenByEngine => 'CHOSEN BY THE ENGINE';

  @override
  String get homeSwitchingServer => 'Switching server…';

  @override
  String get homeGettingServer => 'Getting the server…';

  @override
  String get statusConnected => 'Connected';

  @override
  String homeConnectedClock(String clock) {
    return 'Connected · $clock';
  }

  @override
  String homeStatusAuto(String status) {
    return '$status · auto';
  }

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusError => 'Error';

  @override
  String get statusNotConnected => 'Not connected';

  @override
  String homeGroupRechecks(String summary, int minutes) {
    return '$summary · rechecks every $minutes min';
  }

  @override
  String get startCouldntReadFile => 'Couldn’t read the file';

  @override
  String get startCouldntReadFileDetail =>
      'Try opening it again, or paste its contents.';

  @override
  String get startAddConnection => 'Add a connection';

  @override
  String get startSubtitle => 'Link, subscription or config file';

  @override
  String get startLinkLabel => 'Link or subscription';

  @override
  String get startLinkHint => 'vless://…  or  https://…/sub';

  @override
  String startCantUseThis(String reason) {
    return 'Can’t use this · $reason';
  }

  @override
  String get startOpenConfigFile => 'Open a config file…';

  @override
  String get startOr => 'or';

  @override
  String get startSignInToServer => 'Sign in to your server';

  @override
  String get startOpenSubscriptionPage => 'Open subscription page';

  @override
  String get signInEnterServerFirst => 'Enter the server address first';

  @override
  String get signInNoSsoProviders => 'This server has no SSO providers';

  @override
  String get signInNoSsoProvidersDetail =>
      'Sign in with a username and password instead.';

  @override
  String get signInWith => 'Sign in with';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInSubtitle => 'Your organization’s or personal server';

  @override
  String get signInServerAddress => 'Server address';

  @override
  String get signInServerHint => 'https://your-server';

  @override
  String get signInUsername => 'Username';

  @override
  String get signInPassword => 'Password';

  @override
  String get signInWithSso => 'Sign in with SSO';

  @override
  String get uiNounItem => 'item';

  @override
  String get uiNounServer => 'server';

  @override
  String get uiNounCountry => 'country';

  @override
  String get uiRemoveFromFavorites => 'Remove from favorites';

  @override
  String get uiAddToFavorites => 'Add to favorites';

  @override
  String get uiAllNothingMatches => 'ALL · NOTHING MATCHES';

  @override
  String uiAllMatchCount(int shown, int total) {
    return 'ALL · $shown OF $total MATCH';
  }

  @override
  String uiNoMatches(String noun, String query, int total) {
    return 'No $noun matches “$query”. Clear the search to see all $total.';
  }

  @override
  String get ruleSetModeFullDescription =>
      'All traffic goes through the VPN; rules define exceptions.';

  @override
  String get ruleSetModeSplitDescription =>
      'Only traffic matching the rules goes through the VPN; the rest connects directly.';

  @override
  String get ruleSetNoRulesSplit =>
      'No rules: no traffic goes through the VPN. Add rules for what should be tunneled.';

  @override
  String get ruleSetNoRulesFull =>
      'No rules: all traffic goes through the VPN.';

  @override
  String get ruleSetDownload => 'Download';

  @override
  String get ruleKindRuleList => 'rule list';

  @override
  String ruleInactiveNoDatabase(String kind) {
    return '$kind · inactive — no database';
  }

  @override
  String ruleInactiveDesktopOnly(String kind) {
    return '$kind · inactive — desktop only';
  }

  @override
  String ruleInactiveListsOff(String kind) {
    return '$kind · inactive — lists are off';
  }

  @override
  String ruleInactiveNotDownloaded(String kind) {
    return '$kind · inactive — not downloaded';
  }

  @override
  String ruleNoResolveKind(String kind) {
    return '$kind · no-resolve';
  }

  @override
  String get ruleTypeDomainSuffix => 'domain and subdomains';

  @override
  String get ruleTypeDomainKeyword => 'domain contains';

  @override
  String get ruleTypeDomainExact => 'exact domain';

  @override
  String get ruleTypeIpCidr => 'IP range';

  @override
  String get ruleTypeProcessName => 'app by name';

  @override
  String get ruleTypeGeoip => 'country by IP';

  @override
  String get ruleTypeGeosite => 'domain lists';

  @override
  String get ruleTypeDomainRegex => 'domain matches a pattern';

  @override
  String get ruleTypeRuleList => 'a list from your subscription';

  @override
  String get rulePickCountry => 'Pick a country.';

  @override
  String ruleInvalidValue(String type) {
    return 'Invalid value for $type.';
  }

  @override
  String get ruleMatch => 'Match';

  @override
  String get ruleNotAvailableOnPlatform => 'not available on this platform';

  @override
  String get ruleNeedsGeoDatabases => 'needs geo databases';

  @override
  String get ruleAction => 'Action';

  @override
  String get ruleActionProxyDescription => 'through the VPN';

  @override
  String get ruleActionDirectDescription => 'bypass the VPN';

  @override
  String get ruleActionBlockDescription => 'drop the connection';

  @override
  String get ruleAdd => 'Add rule';

  @override
  String get ruleEdit => 'Edit rule';

  @override
  String get ruleCountry => 'Country';

  @override
  String get ruleChoose => 'Choose…';

  @override
  String get ruleNoResolveDescription =>
      'Match only plain-IP connections, don’t resolve domains';

  @override
  String get ruleValue => 'Value';

  @override
  String ruleSummaryGeoip(String country) {
    return 'traffic to IPs in $country';
  }

  @override
  String ruleSummaryGeosite(String category) {
    return '\"$category\" domains (GeoSite list)';
  }

  @override
  String ruleSummaryProcess(String name) {
    return 'traffic of \"$name\"';
  }

  @override
  String ruleSummaryMatching(String value) {
    return 'traffic matching $value';
  }

  @override
  String get ruleSummaryProxy => 'goes through the VPN';

  @override
  String get ruleSummaryDirect => 'connects directly, bypassing the VPN';

  @override
  String get ruleSummaryBlock => 'is blocked';

  @override
  String ruleSummary(String target, String verb) {
    return '→ $target $verb.';
  }

  @override
  String ruleSetDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get ruleSetDeleteBody =>
      'Configurations using this set fall back to Default.';

  @override
  String get ruleSetDeleteTooltip => 'Delete rule set';

  @override
  String get ruleSetSimple => 'Simple';

  @override
  String get ruleSetDownloadSiteLists => 'Download the site lists first';

  @override
  String get ruleSetDownloadSiteListsDetail =>
      'Picking services needs the geo databases (~25 MB, one time)';

  @override
  String ruleSetAdvancedRules(int count) {
    return 'Advanced rules · $count';
  }

  @override
  String get ruleSetAdvancedRulesDetail =>
      'Apply before the list below · edit in Advanced';

  @override
  String get ruleSetSearchServices => 'Search services';

  @override
  String get ruleSetCountriesHeader => 'COUNTRIES';

  @override
  String get ruleSetAddCountry => 'Add country';

  @override
  String get ruleSetServicesHeader => 'SERVICES';

  @override
  String get ruleSetAddCategory => 'Add category';

  @override
  String get ruleSetOtherCategoriesHeader => 'OTHER CATEGORIES';

  @override
  String get ruleSetNothingSelectedSplit =>
      'Nothing selected · no traffic goes through the VPN yet';

  @override
  String get ruleSetNothingSelectedFull =>
      'Nothing selected · everything goes through the VPN';

  @override
  String ruleSetSelectedSplit(int count) {
    return '$count selected · everything else connects directly';
  }

  @override
  String ruleSetSelectedFull(int count) {
    return '$count selected · they connect directly, the rest goes through the VPN';
  }

  @override
  String get ruleSetOnlySelected => 'Only selected';

  @override
  String get ruleSetAllExceptSelected => 'All except selected';

  @override
  String get ruleSetOnlySelectedDescription =>
      'Only the services you pick go through the VPN. Everything else connects directly.';

  @override
  String get ruleSetAllExceptSelectedDescription =>
      'Everything goes through the VPN. The services you pick connect directly.';

  @override
  String get ruleSetNew => 'New rule set';

  @override
  String get ruleSetNameHint => 'Work';

  @override
  String get ruleSetCreate => 'Create';

  @override
  String ruleSetRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      zero: 'no rules',
    );
    return '$_temp0';
  }

  @override
  String ruleSetUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'used by $count configs',
      one: 'used by 1 config',
    );
    return '$_temp0';
  }

  @override
  String ruleSetSummaryUsed(String mode, String rules, String used) {
    return '$mode · $rules · $used';
  }

  @override
  String get onDemandEnable => 'Enable on demand';

  @override
  String get onDemandEnableSubtitle =>
      'The system applies the first matching rule';

  @override
  String get onDemandNoRules =>
      'No rules. Enabling on demand adds “Connect · Any network”.';

  @override
  String get onDemandRulesFootnote =>
      'Rules are evaluated top to bottom. If none matches, the tunnel is left as is.';

  @override
  String get onDemandTagConnect => 'CONN.';

  @override
  String get onDemandTagDisconnect => 'DISC.';

  @override
  String get onDemandTagIgnore => 'IGNORE';

  @override
  String get onDemandNewRule => 'New rule';

  @override
  String get onDemandActionIgnore => 'Ignore';

  @override
  String get onDemandActionConnectSubtitle => 'bring the tunnel up';

  @override
  String get onDemandActionDisconnectSubtitle => 'tear the tunnel down';

  @override
  String get onDemandActionIgnoreSubtitle => 'leave the tunnel as is';

  @override
  String get onDemandAny => 'Any';

  @override
  String get onDemandNameOptional => 'Name (optional)';

  @override
  String get onDemandNameHint => 'Office';

  @override
  String get onDemandNetworkHeader => 'NETWORK';

  @override
  String get onDemandNetworkHelpAny =>
      'The rule is checked on every network — Wi-Fi, mobile or wired.';

  @override
  String get onDemandNetworkHelpWifi =>
      'When the device joins a Wi-Fi network, the system checks the conditions below and applies the rule.';

  @override
  String get onDemandNetworkHelpCellular =>
      'When the device is on mobile data, the system checks the conditions below and applies the rule.';

  @override
  String get onDemandNetworkHelpEthernet =>
      'When the device is on a wired network, the system checks the conditions below and applies the rule.';

  @override
  String get onDemandConditionsHeader => 'CONDITIONS';

  @override
  String get onDemandWifiNetworks => 'Wi-Fi networks';

  @override
  String get onDemandWifiNetwork => 'Wi-Fi network';

  @override
  String get onDemandNetworksUnit => 'NETWORKS';

  @override
  String get onDemandWifiNetworksHelp =>
      'Matches the network name exactly. Leave empty for any Wi-Fi.';

  @override
  String get onDemandDnsDomains => 'DNS search domains';

  @override
  String get onDemandDnsDomain => 'DNS search domain';

  @override
  String get onDemandDomainsUnit => 'DOMAINS';

  @override
  String get onDemandDnsDomainsHelp =>
      'Matches when the network’s search domain ends with an entry.';

  @override
  String get onDemandDnsServers => 'DNS servers';

  @override
  String get onDemandDnsServer => 'DNS server';

  @override
  String get onDemandServersUnit => 'SERVERS';

  @override
  String get onDemandDnsServersHelp =>
      'Matches the network’s DNS servers; a single “*” wildcard is allowed.';

  @override
  String get onDemandUrlProbeHeader => 'URL PROBE';

  @override
  String get onDemandUrlOptional => 'URL (optional)';

  @override
  String get onDemandUrlProbeHelp =>
      'The rule matches only if this URL returns 200 without redirects.';

  @override
  String get onDemandNoEntries => 'NO ENTRIES';

  @override
  String onDemandEntriesHeader(int count, String unit) {
    return '$count $unit · ANY OF THEM MATCHES';
  }

  @override
  String get onDemandConditionIgnored =>
      'The condition is ignored and the rule matches any network of the selected type.';

  @override
  String get onDemandInterfaceAny => 'Any network';

  @override
  String get onDemandInterfaceWifi => 'Wi-Fi';

  @override
  String get onDemandInterfaceCellular => 'Mobile';

  @override
  String get onDemandInterfaceEthernet => 'Ethernet';

  @override
  String onDemandSummarySsid(String values) {
    return 'SSID $values';
  }

  @override
  String onDemandSummaryDomain(String values) {
    return 'domain $values';
  }

  @override
  String onDemandSummaryDns(String values) {
    return 'DNS $values';
  }

  @override
  String get onDemandSummaryProbe => 'probe';

  @override
  String get onDemandStatusPaused => 'Paused';

  @override
  String get onDemandStatusAwaitingFirstConnect => 'On · after first connect';

  @override
  String onDemandStatusOnRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On · $count rules',
      one: 'On · 1 rule',
    );
    return '$_temp0';
  }

  @override
  String get onDemandDefaultRuleName => 'Everywhere';

  @override
  String get statusNoConfiguration => 'No configuration';

  @override
  String get menuBarSwitching => 'Switching…';

  @override
  String profilesCouldntGetServer(String label) {
    return 'Couldn’t get the server for $label';
  }

  @override
  String get profilesPreviousServerStillInUse =>
      'The previous one is still in use.';

  @override
  String get profilesCouldntSwitch => 'Couldn’t switch';

  @override
  String get profilesCouldntSwitchDetail =>
      'The tunnel kept the previous configuration. Try again, or reconnect.';

  @override
  String get profilesNoConfigurationDetail =>
      'Add a link, a subscription, or sign in to your server.';

  @override
  String get profilesNoServers => 'This configuration has no servers';

  @override
  String get profilesNoServersDetail =>
      'Refresh it, or add another configuration.';

  @override
  String get profilesTunnelStopped => 'The tunnel stopped';

  @override
  String get connectionCheckTimedOut => 'The server did not answer in time.';

  @override
  String get connectionCheckClosed => 'The server closed the connection.';

  @override
  String get connectionCheckRefused => 'The server refused the connection.';

  @override
  String get connectionCheckNoServer =>
      'There is no server to test — the tunnel is running something else.';

  @override
  String get connectionCheckTunnelNotRunning => 'The tunnel is not running.';

  @override
  String get connectionCheckNothingCameBack => 'Nothing came back.';

  @override
  String get connectionCheckEngineDidNotAnswer => 'The engine did not answer.';

  @override
  String get errorDeviceLimitTitle => 'Device limit reached';

  @override
  String get errorDeviceLimitDetail =>
      'Your subscription’s device limit is full, so it sent a placeholder instead of your servers. Free a slot in your subscription, then refresh.';

  @override
  String get errorUnreadableSubscriptionTitle =>
      'Couldn’t read this subscription';

  @override
  String get errorUnreadableSubscriptionDetail =>
      'Your subscription sent a format this app does not recognise. It reads base64 link lists, Clash / mihomo, Xray JSON and sing-box. Nothing was added.';

  @override
  String get errorEmptySubscriptionTitle => 'This subscription has no servers';

  @override
  String errorEmptySubscriptionDetail(String what) {
    return 'Your subscription answered with $what that lists none. That usually means the account is out of days or its device limit is full — ask them.';
  }

  @override
  String errorNoRunnableServersTitle(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'None of the $total servers can run here',
      one: 'The only server here cannot run',
    );
    return '$_temp0';
  }

  @override
  String errorNoRunnableServersDetail(String kinds) {
    return 'They use $kinds, which this app cannot run yet. Nothing was added.';
  }

  @override
  String get errorProviderMessageTitle => 'Your subscription sent a message';

  @override
  String errorProviderMessageDetail(String lines) {
    return '$lines\n\nNot servers: every entry points nowhere, so nothing was added.';
  }

  @override
  String get errorSubjectDefault => 'the server';

  @override
  String get errorServerDidNotAnswerTitle => 'Server didn’t answer';

  @override
  String errorCouldNotReachDetail(String what) {
    return 'Couldn’t reach $what. Check your network, or pick another server.';
  }

  @override
  String get errorSecureConnectionTitle =>
      'Couldn’t set up a secure connection';

  @override
  String errorCertificateRejectedDetail(String what) {
    return 'The certificate of $what was rejected. If the address is right, the server may be misconfigured.';
  }

  @override
  String errorConnectionClosedDetail(String what) {
    return 'The connection to $what was closed.';
  }

  @override
  String get errorWrongCredentialsTitle => 'Wrong username or password';

  @override
  String get errorWrongCredentialsDetail => 'Check both and try again.';

  @override
  String get errorSessionExpiredTitle => 'Session expired';

  @override
  String errorSessionExpiredDetail(String what) {
    return 'Sign in to $what again.';
  }

  @override
  String get errorAccessBlockedTitle => 'Access is blocked';

  @override
  String get errorAccessBlockedDetail => 'The server refused this account.';

  @override
  String get errorNothingAtAddressTitle => 'Nothing at this address';

  @override
  String errorNothingAtAddressDetail(String what) {
    return 'Check the link — $what has no configuration for this account.';
  }

  @override
  String get errorServerErrorTitle => 'The server returned an error';

  @override
  String get errorServerErrorDetail =>
      'Nothing to fix on this side — try again in a few minutes.';

  @override
  String get errorServerRefusedTitle => 'The server refused the request';

  @override
  String get errorNotALinkTitle => 'This doesn’t look like a link we know';

  @override
  String get errorNotALinkDetail =>
      'Expected vless://, vmess://, trojan://, ss:// or a subscription URL.';

  @override
  String get errorTunnelServiceNotRunningTitle =>
      'The tunnel service isn’t running';

  @override
  String get errorTunnelServiceNotRunningDetail =>
      'AnnoyaTest installs it as the “AnnoyaTunnel” Windows service. Reinstall the app, or start the service in Services, then connect again.';

  @override
  String get errorTunnelServiceStoppedTitle => 'The tunnel service stopped';

  @override
  String get errorTunnelServiceStoppedDetail =>
      'It restarts on its own within a few seconds — connect again. If this keeps happening, the tunnel log in Settings → Logs says why.';

  @override
  String get errorSystemRefusedTunnelTitle =>
      'The system refused to start the tunnel';

  @override
  String get errorSystemRefusedTunnelDetail =>
      'Allow the VPN profile in system settings, then connect again.';

  @override
  String get errorSignInNotFinishedTitle => 'Sign-in didn’t finish';

  @override
  String get errorSignInNotFinishedDetail =>
      'The browser window was closed or the provider refused.';

  @override
  String get errorSomethingWentWrongTitle => 'Something went wrong';

  @override
  String get errorSomethingWentWrongDetail =>
      'The details are in Settings → Logs.';

  @override
  String get errorDeviceNotAcceptedTitle =>
      'Your subscription did not accept this device';

  @override
  String get errorDeviceNotAcceptedDetail =>
      'It requires a device id this app did send. Ask your subscription’s support.';

  @override
  String errorApiTimeout(String baseUrl) {
    return 'No answer from $baseUrl — check the address and the network.';
  }

  @override
  String errorApiNetwork(String baseUrl) {
    return 'Cannot reach $baseUrl — check the address/port and that the server is up.';
  }

  @override
  String errorApiTls(String baseUrl) {
    return 'TLS error talking to $baseUrl. If the server runs plain HTTP, enter the address with \"http://\".';
  }

  @override
  String errorApiRequest(String baseUrl) {
    return 'The request to $baseUrl could not be completed — check the address and try again.';
  }

  @override
  String get accountExpiredDetail =>
      'Renew it in your account, then connect again.';

  @override
  String get accountLimitedTitle => 'Traffic limit reached';

  @override
  String get accountLimitedDetail => 'The plan is used up until it renews.';

  @override
  String get accountDeactivatedTitle => 'Access disabled';

  @override
  String get accountDeactivatedDetail =>
      'The administrator turned this account off.';

  @override
  String get accountOnHoldTitle => 'Subscription not started';

  @override
  String get accountOnHoldDetail =>
      'It begins on the first connection — try again in a moment.';

  @override
  String accountOtherStateTitle(String state) {
    return 'Account is $state';
  }

  @override
  String get accountOtherStateDetail =>
      'Connecting is not allowed in this state.';

  @override
  String get amneziaErrorEmptyAnswerTitle => 'The gateway sent nothing';

  @override
  String get amneziaErrorEmptyAnswerDetail =>
      'It answered without a configuration. Try again; if it repeats, support for this subscription will need to look.';

  @override
  String get amneziaErrorCancelledTitle => 'Took too long';

  @override
  String get amneziaErrorCancelledDetail =>
      'The gateway did not answer in time. Check the connection and try again.';

  @override
  String get amneziaErrorNetworkTitle => 'Couldn’t reach the gateway';

  @override
  String get amneziaErrorNetworkDetail =>
      'The gateway did not answer. This is usually the network, not the subscription — try again in a moment.';

  @override
  String get amneziaErrorTimeoutTitle => 'The gateway timed out';

  @override
  String get amneziaErrorTimeoutDetail =>
      'No answer within the time allowed. Check the connection and try again.';

  @override
  String get amneziaErrorSslTitle => 'The connection was not trusted';

  @override
  String get amneziaErrorSslDetail =>
      'Something interfered with the secure connection to the gateway.';

  @override
  String get amneziaErrorConfigTitle => 'This build cannot talk to the gateway';

  @override
  String get amneziaErrorConfigDetail =>
      'It was built without the gateway credentials, so subscriptions of this kind are unavailable in it.';

  @override
  String get amneziaErrorDecryptTitle => 'The answer could not be read';

  @override
  String get amneziaErrorDecryptDetail =>
      'The reply was not what the gateway should have sent — often a network that intercepts traffic.';

  @override
  String get amneziaErrorInvalidArgumentTitle =>
      'The gateway request was malformed';

  @override
  String get amneziaErrorInvalidArgumentDetail =>
      'A defect in this app, not in the subscription. Restarting the app helps; if it repeats, the log in Settings → Logs is what support needs.';

  @override
  String get amneziaErrorRefusedTitle => 'The gateway refused the request';

  @override
  String amneziaErrorRefusedCodeDetail(int code) {
    return 'The gateway answered with code $code.';
  }

  @override
  String amneziaErrorRefusedHttpDetail(int status) {
    return 'The gateway answered with HTTP $status.';
  }

  @override
  String get amneziaErrorTooManyRequestsTitle => 'Too many requests';

  @override
  String get amneziaErrorTooManyRequestsDetail =>
      'The gateway is throttling this subscription. Wait a few minutes before trying again.';

  @override
  String get amneziaErrorTrialUsedTitle => 'Trial already used';

  @override
  String get amneziaErrorTrialUsedDetail =>
      'This address has already activated a trial.';

  @override
  String get amneziaErrorDeviceLimitDetail =>
      'This subscription is already installed on as many devices as it allows. Remove one from the subscription, then try again.';

  @override
  String get amneziaErrorNotFoundTitle => 'Subscription not found';

  @override
  String get amneziaErrorNotFoundDetail =>
      'The gateway does not recognise this key. Check that it was pasted whole.';

  @override
  String get amneziaErrorNewerClientTitle =>
      'The gateway requires a newer client';

  @override
  String get amneziaErrorNewerClientDetail =>
      'The gateway refused this app’s version. It will work again once the app is updated.';

  @override
  String get amneziaErrorCaptchaPass =>
      'Pass it in the app this subscription came from, then refresh here.';

  @override
  String get amneziaErrorCaptchaExpiredTitle => 'The CAPTCHA expired';

  @override
  String get amneziaErrorCaptchaRejectedTitle => 'The CAPTCHA was rejected';

  @override
  String get amneziaErrorCaptchaAskedTitle => 'The gateway asked for a CAPTCHA';

  @override
  String amneziaErrorCaptchaAskedDetail(String pass) {
    return 'This app cannot show one. $pass';
  }

  @override
  String get amneziaErrorNotActiveTitle => 'Subscription not active';

  @override
  String get amneziaErrorNotActiveDetail =>
      'The gateway has no active subscription for this key.';

  @override
  String get amneziaErrorLostKeyTitle => 'This subscription lost its key';

  @override
  String get amneziaErrorLostKeyDetail =>
      'Remove the configuration and add it again.';

  @override
  String get amneziaErrorFreeTierUnsupported =>
      'This subscription is free-tier, and its gateway asks for a CAPTCHA before it issues a configuration — which this app cannot show. Use the app it came from, or add a paid key here.';

  @override
  String get importNotAKeyTitle => 'This isn’t a subscription key';

  @override
  String get importNotAKeyDetail =>
      'Expected a vpn:// key from your subscription.';

  @override
  String importKeyUnsupportedTitle(String name) {
    return '$name isn’t supported here';
  }

  @override
  String importImportedName(int count) {
    return 'Imported ($count)';
  }

  @override
  String get importFormatLinks => 'a link list';

  @override
  String get importFormatClash => 'a Clash / mihomo subscription';

  @override
  String get importFormatXray => 'an Xray JSON subscription';

  @override
  String get importFormatSingbox => 'a sing-box subscription';

  @override
  String get importFormatUnknown => 'something unrecognised';

  @override
  String importDetectedAmneziaKey(String name) {
    return '$name · subscription key';
  }

  @override
  String importDetectedServer(String type, String label) {
    return '$type server · $label';
  }

  @override
  String importDetectedSubscriptionUrl(String host) {
    return 'Subscription URL · $host';
  }

  @override
  String importDetectedSingleServer(String label) {
    return 'Server · $label';
  }

  @override
  String importDetectedSubscriptionText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return 'Subscription · $_temp0';
  }

  @override
  String get importUnusableNotAmneziaKey => 'Not an Amnezia subscription key';

  @override
  String importUnusableNotSupported(String what) {
    return '$what isn’t supported';
  }

  @override
  String importUnusableTransportNotSupported(String scheme, String transport) {
    return '$scheme over $transport isn’t supported';
  }

  @override
  String importUnusableLinkUnreadable(String scheme) {
    return '$scheme:// link can’t be read';
  }

  @override
  String get importUnusableNotALink => 'Not a link or subscription';

  @override
  String get catalogGroupStreaming => 'STREAMING';

  @override
  String get catalogGroupMessengers => 'MESSENGERS';

  @override
  String get catalogGroupSocial => 'SOCIAL';

  @override
  String get catalogGroupOther => 'OTHER';

  @override
  String proxyGroupUrlTest(int count) {
    return 'Lowest latency of $count';
  }

  @override
  String proxyGroupFallback(int count) {
    return 'First of $count that answers · in their order';
  }

  @override
  String proxyGroupLoadBalance(int count) {
    return 'Spread across $count';
  }

  @override
  String proxyGroupRelay(int count) {
    return 'Chain of $count';
  }
}
