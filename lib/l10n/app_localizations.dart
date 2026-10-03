import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get commonConnect;

  /// No description provided for @commonDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get commonDisconnect;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get commonAll;

  /// No description provided for @commonFavorites.
  ///
  /// In en, this message translates to:
  /// **'FAVORITES'**
  String get commonFavorites;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Relative time: an event less than a minute ago
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get commonJustNow;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'CONFIGURATIONS'**
  String get settingsSectionConfigurations;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'CONNECTION'**
  String get settingsSectionConnection;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'ROUTING'**
  String get settingsSectionRouting;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get settingsSectionGeneral;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTICS'**
  String get settingsSectionDiagnostics;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsConfigurations.
  ///
  /// In en, this message translates to:
  /// **'Configurations'**
  String get settingsConfigurations;

  /// No description provided for @settingsConfigurationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 configuration} other{{count} configurations}}'**
  String settingsConfigurationsCount(int count);

  /// Singular noun inserted into the picker's empty-search message: 'No configuration matches ...'
  ///
  /// In en, this message translates to:
  /// **'configuration'**
  String get uiNounConfiguration;

  /// No description provided for @settingsAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect'**
  String get settingsAutoConnect;

  /// No description provided for @settingsAutoConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect when the computer starts'**
  String get settingsAutoConnectSubtitle;

  /// No description provided for @onDemandTitle.
  ///
  /// In en, this message translates to:
  /// **'On demand'**
  String get onDemandTitle;

  /// No description provided for @settingsDisconnectOnSleep.
  ///
  /// In en, this message translates to:
  /// **'Disconnect on sleep'**
  String get settingsDisconnectOnSleep;

  /// No description provided for @settingsDisconnectOnSleepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop the tunnel when the device sleeps'**
  String get settingsDisconnectOnSleepSubtitle;

  /// No description provided for @settingsAlwaysOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A system switch — set in Android settings'**
  String get settingsAlwaysOnSubtitle;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsConnectionCheckOn.
  ///
  /// In en, this message translates to:
  /// **'Connection check · on'**
  String get settingsConnectionCheckOn;

  /// No description provided for @settingsConnectionCheckOff.
  ///
  /// In en, this message translates to:
  /// **'Connection check · off'**
  String get settingsConnectionCheckOff;

  /// No description provided for @settingsLanDirect.
  ///
  /// In en, this message translates to:
  /// **'Local network direct'**
  String get settingsLanDirect;

  /// No description provided for @settingsLanDirectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'LAN traffic bypasses the VPN'**
  String get settingsLanDirectSubtitle;

  /// No description provided for @ruleSetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule sets'**
  String get ruleSetsTitle;

  /// No description provided for @settingsRuleSetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String settingsRuleSetCount(int count);

  /// No description provided for @settingsDefaultDns.
  ///
  /// In en, this message translates to:
  /// **'Default DNS'**
  String get settingsDefaultDns;

  /// No description provided for @settingsDefaultDnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} · used when a configuration brings none'**
  String settingsDefaultDnsSubtitle(String name);

  /// No description provided for @settingsDnsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get settingsDnsCustom;

  /// No description provided for @settingsDnsCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'any address the engine accepts'**
  String get settingsDnsCustomSubtitle;

  /// No description provided for @settingsDnsResolverLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolver'**
  String get settingsDnsResolverLabel;

  /// No description provided for @settingsDnsUseCloudflare.
  ///
  /// In en, this message translates to:
  /// **'Use Cloudflare'**
  String get settingsDnsUseCloudflare;

  /// No description provided for @settingsGeoDownloaded.
  ///
  /// In en, this message translates to:
  /// **'downloaded · {size}'**
  String settingsGeoDownloaded(String size);

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the device setting'**
  String get settingsThemeSystemSubtitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get aboutEngine;

  /// No description provided for @aboutVersionCopied.
  ///
  /// In en, this message translates to:
  /// **'Version copied'**
  String get aboutVersionCopied;

  /// No description provided for @aboutTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get aboutTermsOfService;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutNotPublishedYet.
  ///
  /// In en, this message translates to:
  /// **'Not published yet'**
  String get aboutNotPublishedYet;

  /// No description provided for @uiCouldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open that page.'**
  String get uiCouldNotOpenPage;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'CONNECTION CHECK'**
  String get advancedSectionConnectionCheck;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'LAST CHECK'**
  String get advancedSectionLastCheck;

  /// No description provided for @advancedCheckAfterConnecting.
  ///
  /// In en, this message translates to:
  /// **'Check after connecting'**
  String get advancedCheckAfterConnecting;

  /// No description provided for @advancedCheckAfterConnectingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch a page through the server and time the answer'**
  String get advancedCheckAfterConnectingSubtitle;

  /// No description provided for @advancedTestUrl.
  ///
  /// In en, this message translates to:
  /// **'Test URL'**
  String get advancedTestUrl;

  /// No description provided for @advancedUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get advancedUrlLabel;

  /// No description provided for @advancedUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the default'**
  String get advancedUseDefault;

  /// No description provided for @advancedInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter an http:// or https:// address.'**
  String get advancedInvalidUrl;

  /// No description provided for @advancedGiveUpAfter.
  ///
  /// In en, this message translates to:
  /// **'Give up after'**
  String get advancedGiveUpAfter;

  /// No description provided for @advancedSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String advancedSeconds(int count);

  /// No description provided for @advancedTestNow.
  ///
  /// In en, this message translates to:
  /// **'Test now'**
  String get advancedTestNow;

  /// No description provided for @advancedNeedsTunnelNote.
  ///
  /// In en, this message translates to:
  /// **'The request goes through the running engine, so the tunnel has to be up to test it.'**
  String get advancedNeedsTunnelNote;

  /// No description provided for @advancedCheckScopeNote.
  ///
  /// In en, this message translates to:
  /// **'The request goes through the server itself, so routing rules do not affect it. It proves the server passes traffic — not that your traffic goes through it.'**
  String get advancedCheckScopeNote;

  /// No description provided for @advancedNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get advancedNoAnswer;

  /// No description provided for @advancedNoAnswerDetail.
  ///
  /// In en, this message translates to:
  /// **'{failure} The tunnel is up, so this is the server or the network beyond it.'**
  String advancedNoAnswerDetail(String failure);

  /// No description provided for @advancedTrafficGettingThrough.
  ///
  /// In en, this message translates to:
  /// **'Traffic is getting through'**
  String get advancedTrafficGettingThrough;

  /// No description provided for @advancedAnsweredIn.
  ///
  /// In en, this message translates to:
  /// **'Answered in {ms} ms'**
  String advancedAnsweredIn(int ms);

  /// When the check ran, and which server carried it
  ///
  /// In en, this message translates to:
  /// **'{ago} · through {via}'**
  String advancedResultVia(String ago, String via);

  /// No description provided for @commonMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String commonMinutesAgo(int count);

  /// No description provided for @advancedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String advancedHoursAgo(int count);

  /// No description provided for @alwaysOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Always-on VPN'**
  String get alwaysOnTitle;

  /// No description provided for @alwaysOnStartedBySystem.
  ///
  /// In en, this message translates to:
  /// **'Started by the system'**
  String get alwaysOnStartedBySystem;

  /// No description provided for @alwaysOnStartedBySystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At boot, and again whenever the tunnel drops'**
  String get alwaysOnStartedBySystemSubtitle;

  /// No description provided for @alwaysOnBlockWithoutVpn.
  ///
  /// In en, this message translates to:
  /// **'Block connections without VPN'**
  String get alwaysOnBlockWithoutVpn;

  /// No description provided for @alwaysOnBlockWithoutVpnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The system’s kill switch, on the same screen'**
  String get alwaysOnBlockWithoutVpnSubtitle;

  /// No description provided for @alwaysOnNote.
  ///
  /// In en, this message translates to:
  /// **'Android owns this switch, so it lives in system settings: Network & internet → VPN → the gear next to this app. The system starts whatever configuration was used last.'**
  String get alwaysOnNote;

  /// No description provided for @alwaysOnOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system VPN settings'**
  String get alwaysOnOpenSystemSettings;

  /// No description provided for @dnsTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dnsTitle;

  /// Section header, all caps: the resolvers currently in use
  ///
  /// In en, this message translates to:
  /// **'IN EFFECT'**
  String get dnsSectionInEffect;

  /// Section header, all caps: resolvers the app refused to use
  ///
  /// In en, this message translates to:
  /// **'DROPPED'**
  String get dnsSectionDropped;

  /// No description provided for @dnsParallelNote.
  ///
  /// In en, this message translates to:
  /// **'Asked at the same time; the first answer wins.'**
  String get dnsParallelNote;

  /// No description provided for @dnsFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'This configuration names no resolver of its own, so the app uses its default — change it in Settings › Default DNS.'**
  String get dnsFallbackNote;

  /// No description provided for @dnsProviderNote.
  ///
  /// In en, this message translates to:
  /// **'Chosen by whoever set up this configuration, and it changes with it.'**
  String get dnsProviderNote;

  /// No description provided for @dnsProxyResolvedDirectlyNote.
  ///
  /// In en, this message translates to:
  /// **'The address of the server you connect through is always resolved directly. It has to be — nothing could reach the tunnel otherwise.'**
  String get dnsProxyResolvedDirectlyNote;

  /// No description provided for @dnsResolverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{protocol} · {origin}'**
  String dnsResolverSubtitle(String protocol, String origin);

  /// No description provided for @dnsPinIgnoredTooltip.
  ///
  /// In en, this message translates to:
  /// **'This configuration asked for an outbound this app does not create, so the request was dropped and the resolver is reached directly.'**
  String get dnsPinIgnoredTooltip;

  /// No description provided for @dnsOriginAppDefault.
  ///
  /// In en, this message translates to:
  /// **'app default'**
  String get dnsOriginAppDefault;

  /// No description provided for @dnsOriginSubscription.
  ///
  /// In en, this message translates to:
  /// **'from your subscription'**
  String get dnsOriginSubscription;

  /// No description provided for @dnsOriginOrganisation.
  ///
  /// In en, this message translates to:
  /// **'from your organisation'**
  String get dnsOriginOrganisation;

  /// No description provided for @dnsOriginConfiguration.
  ///
  /// In en, this message translates to:
  /// **'from this configuration'**
  String get dnsOriginConfiguration;

  /// How a resolver is reached: off the physical interface, not through the tunnel
  ///
  /// In en, this message translates to:
  /// **'direct'**
  String get dnsRoutingDirect;

  /// No description provided for @dnsRoutingFollowsRules.
  ///
  /// In en, this message translates to:
  /// **'follows your rules'**
  String get dnsRoutingFollowsRules;

  /// No description provided for @dnsRoutingThroughTunnel.
  ///
  /// In en, this message translates to:
  /// **'through the tunnel'**
  String get dnsRoutingThroughTunnel;

  /// No description provided for @dnsProtocolDoh.
  ///
  /// In en, this message translates to:
  /// **'DNS over HTTPS'**
  String get dnsProtocolDoh;

  /// No description provided for @dnsProtocolDot.
  ///
  /// In en, this message translates to:
  /// **'DNS over TLS'**
  String get dnsProtocolDot;

  /// No description provided for @dnsProtocolDoq.
  ///
  /// In en, this message translates to:
  /// **'DNS over QUIC'**
  String get dnsProtocolDoq;

  /// No description provided for @dnsProtocolPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain, unencrypted'**
  String get dnsProtocolPlain;

  /// No description provided for @dnsDropMalformed.
  ///
  /// In en, this message translates to:
  /// **'Not a resolver address. Nothing from a subscription is put into the engine configuration unchecked.'**
  String get dnsDropMalformed;

  /// No description provided for @dnsDropUnknownScheme.
  ///
  /// In en, this message translates to:
  /// **'The engine has no scheme for this. Keeping it would have failed the whole configuration, not just this line.'**
  String get dnsDropUnknownScheme;

  /// No description provided for @dnsDropCannotCarry.
  ///
  /// In en, this message translates to:
  /// **'Plain DNS cannot travel through this server, and sending it outside the tunnel would show every site you visit to your network.'**
  String get dnsDropCannotCarry;

  /// No description provided for @dnsDropTooMany.
  ///
  /// In en, this message translates to:
  /// **'Past the {max} the engine is given. It asks them all at once, so a longer list costs time without answering better.'**
  String dnsDropTooMany(int max);

  /// No description provided for @dnsPresetQuad9Note.
  ///
  /// In en, this message translates to:
  /// **'filters known-malicious domains'**
  String get dnsPresetQuad9Note;

  /// No description provided for @dnsPresetAdGuardNote.
  ///
  /// In en, this message translates to:
  /// **'filters ads and trackers'**
  String get dnsPresetAdGuardNote;

  /// No description provided for @dnsErrorNotResolverAddress.
  ///
  /// In en, this message translates to:
  /// **'Not a resolver address.'**
  String get dnsErrorNotResolverAddress;

  /// No description provided for @dnsErrorAddressedByName.
  ///
  /// In en, this message translates to:
  /// **'Addressed by name, so it would need resolving before it could resolve anything. Use its IP address.'**
  String get dnsErrorAddressedByName;

  /// No description provided for @geoTitle.
  ///
  /// In en, this message translates to:
  /// **'GeoIP & GeoSite'**
  String get geoTitle;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'DATABASES'**
  String get geoSectionDatabases;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'UPDATES'**
  String get geoSectionUpdates;

  /// No description provided for @geoGeoipSource.
  ///
  /// In en, this message translates to:
  /// **'GeoIP source'**
  String get geoGeoipSource;

  /// No description provided for @geoGeositeSource.
  ///
  /// In en, this message translates to:
  /// **'GeoSite source'**
  String get geoGeositeSource;

  /// No description provided for @geoDownloadUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Download URL'**
  String get geoDownloadUrlLabel;

  /// No description provided for @geoResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get geoResetToDefault;

  /// No description provided for @geoNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'not downloaded'**
  String get geoNotDownloaded;

  /// Shown under 'Last updated' when the databases were never downloaded
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get geoNever;

  /// No description provided for @commonDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String commonDaysAgo(int count);

  /// No description provided for @commonHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String commonHoursAgo(int count);

  /// No description provided for @geoLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get geoLastUpdated;

  /// No description provided for @geoAutoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto-update'**
  String get geoAutoUpdate;

  /// No description provided for @geoAutoUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly, when already downloaded'**
  String get geoAutoUpdateSubtitle;

  /// No description provided for @geoUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get geoUpdateNow;

  /// No description provided for @geoDownload.
  ///
  /// In en, this message translates to:
  /// **'Download (~25 MB)'**
  String get geoDownload;

  /// What failed, inserted into an error sentence such as 'Could not reach {subject}'
  ///
  /// In en, this message translates to:
  /// **'the database host'**
  String get geoDatabaseHostSubject;

  /// No description provided for @geositeCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get geositeCategoryLabel;

  /// No description provided for @geositeDomainCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 domain} other{{count} domains}}'**
  String geositeDomainCount(int count);

  /// No description provided for @geositeNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories — download the geo databases first.'**
  String get geositeNoCategories;

  /// No description provided for @uiNothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String uiNothingMatches(String query);

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'POPULAR'**
  String get geositeSectionPopular;

  /// Section header, all caps: every category with its count
  ///
  /// In en, this message translates to:
  /// **'ALL · {count}'**
  String geositeSectionAll(int count);

  /// Section header, all caps: how many categories match the search
  ///
  /// In en, this message translates to:
  /// **'ALL · {count} OF {total} MATCH'**
  String geositeSectionAllMatch(int count, int total);

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'COLLECTION'**
  String get logsSectionCollection;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'TUNNEL'**
  String get logsSectionTunnel;

  /// Section header, all caps
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get logsSectionApp;

  /// No description provided for @logsCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect logs'**
  String get logsCollect;

  /// No description provided for @logsCollectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off: the app, the tunnel and the core stop writing. Existing files stay readable.'**
  String get logsCollectSubtitle;

  /// No description provided for @logsTunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get logsTunnel;

  /// No description provided for @logsTunnelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network Extension events'**
  String get logsTunnelSubtitle;

  /// No description provided for @logsCore.
  ///
  /// In en, this message translates to:
  /// **'Core (mihomo)'**
  String get logsCore;

  /// No description provided for @logsCoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Engine log: dials, DNS, routing'**
  String get logsCoreSubtitle;

  /// No description provided for @logsApplication.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get logsApplication;

  /// No description provided for @logsApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Client-side events'**
  String get logsApplicationSubtitle;

  /// No description provided for @logsSaveAllZip.
  ///
  /// In en, this message translates to:
  /// **'Save all logs (.zip)'**
  String get logsSaveAllZip;

  /// No description provided for @logsSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save all logs'**
  String get logsSaveAll;

  /// No description provided for @logsSaveToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to file…'**
  String get logsSaveToFile;

  /// No description provided for @logsSaveToFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder on this device'**
  String get logsSaveToFileSubtitle;

  /// No description provided for @logsShare.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get logsShare;

  /// No description provided for @logsShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send the archive somewhere'**
  String get logsShareSubtitle;

  /// No description provided for @logsSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save logs'**
  String get logsSaveDialogTitle;

  /// No description provided for @logsSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String logsSavedTo(String path);

  /// No description provided for @logsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs'**
  String get logsClearAll;

  /// No description provided for @logsClearAllQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs?'**
  String get logsClearAllQuestion;

  /// No description provided for @logsClearAllContent.
  ///
  /// In en, this message translates to:
  /// **'The app, tunnel and core logs will be deleted from this device.'**
  String get logsClearAllContent;

  /// No description provided for @logsCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared.'**
  String get logsCleared;

  /// No description provided for @logsAppLogClearedOnly.
  ///
  /// In en, this message translates to:
  /// **'App log cleared. The tunnel and core logs need the VPN connected.'**
  String get logsAppLogClearedOnly;

  /// No description provided for @logsNoLog.
  ///
  /// In en, this message translates to:
  /// **'No log.'**
  String get logsNoLog;

  /// No description provided for @logsNoLogYet.
  ///
  /// In en, this message translates to:
  /// **'No log yet.'**
  String get logsNoLogYet;

  /// Log viewer body when the log has no content
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get logsEmpty;

  /// No description provided for @logsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Logs are available only while the tunnel is running.\n(The tunnel process keeps its logs on its own side and streams them to the app over IPC.)'**
  String get logsUnavailable;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @configKindSelfhosted.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted · {servers}'**
  String configKindSelfhosted(String servers);

  /// No description provided for @configKindSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription · {servers}{groups}'**
  String configKindSubscription(String servers, String groups);

  /// Name of an imported subscription whose key carries no name
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get configKindSubscriptionPlain;

  /// No description provided for @configKindSingleServer.
  ///
  /// In en, this message translates to:
  /// **'Single server'**
  String get configKindSingleServer;

  /// No description provided for @commonServersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server} other{{count} servers}}'**
  String commonServersCount(int count);

  /// No description provided for @configServersOfOffered.
  ///
  /// In en, this message translates to:
  /// **'{offered, plural, =1{{ours} of 1 server} other{{ours} of {offered} servers}}'**
  String configServersOfOffered(int ours, int offered);

  /// Appended to the subscription kind line after the server count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{ · 1 group} other{ · {count} groups}}'**
  String configGroupsSuffix(int count);

  /// No description provided for @configSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get configSource;

  /// No description provided for @configSourceViaFallback.
  ///
  /// In en, this message translates to:
  /// **'Last refresh used the subscription’s backup address'**
  String get configSourceViaFallback;

  /// No description provided for @configCouldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open that link.'**
  String get configCouldNotOpenLink;

  /// No description provided for @configLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get configLinkCopied;

  /// No description provided for @configUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'{skipped} of {offered} servers unsupported'**
  String configUnsupportedTitle(int skipped, int offered);

  /// No description provided for @configUnsupportedDetail.
  ///
  /// In en, this message translates to:
  /// **'They use {kinds}, which this app cannot run yet. The other {available} are available.'**
  String configUnsupportedDetail(String kinds, int available);

  /// No description provided for @configSetActive.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get configSetActive;

  /// No description provided for @configRemoveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Remove configuration'**
  String get configRemoveConfiguration;

  /// No description provided for @configRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String configRemoveTitle(String name);

  /// No description provided for @configRemoveDetail.
  ///
  /// In en, this message translates to:
  /// **'This configuration will be removed from this device.'**
  String get configRemoveDetail;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTION'**
  String get configSectionSubscription;

  /// No description provided for @configRanUntil.
  ///
  /// In en, this message translates to:
  /// **'Ran until'**
  String get configRanUntil;

  /// No description provided for @configRunsUntil.
  ///
  /// In en, this message translates to:
  /// **'Runs until'**
  String get configRunsUntil;

  /// No description provided for @configDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get configDevices;

  /// No description provided for @configDevicesUsed.
  ///
  /// In en, this message translates to:
  /// **'{active} of {max} used'**
  String configDevicesUsed(int active, int max);

  /// A date such as 21 September 2026
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String configDateLong(DateTime date);

  /// A date such as 21 Sep 2026
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String configDateShort(DateTime date);

  /// No description provided for @configDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count, plural, =1{1 day left} other{{count} days left}}'**
  String configDaysLeft(String date, int count);

  /// No description provided for @accountExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription expired'**
  String get accountExpiredTitle;

  /// No description provided for @configSubscriptionExpiredDetail.
  ///
  /// In en, this message translates to:
  /// **'Renew the subscription, then refresh this configuration.'**
  String get configSubscriptionExpiredDetail;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get configSectionThisDevice;

  /// No description provided for @configDeviceIdentifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identified to your subscription, which counts devices'**
  String get configDeviceIdentifiedSubtitle;

  /// No description provided for @configDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device id'**
  String get configDeviceId;

  /// No description provided for @configDeviceHintAmnezia.
  ///
  /// In en, this message translates to:
  /// **'Your subscription counts devices by this id. It is made once and kept, so reconnecting costs no slot — but a reinstall takes a new one.'**
  String get configDeviceHintAmnezia;

  /// No description provided for @configDeviceHintPanel.
  ///
  /// In en, this message translates to:
  /// **'Your subscription counts devices by an id this app generates once and keeps. Reinstalling makes a new one, which takes another slot.'**
  String get configDeviceHintPanel;

  /// Toast after copying the identifier named by title, e.g. 'Device id copied'
  ///
  /// In en, this message translates to:
  /// **'{title} copied'**
  String configCopiedTitle(String title);

  /// No description provided for @configDnsSummary.
  ///
  /// In en, this message translates to:
  /// **'{host} · {routing}'**
  String configDnsSummary(String host, String routing);

  /// Appended to the DNS summary when more resolvers follow the first
  ///
  /// In en, this message translates to:
  /// **' · +{count} more'**
  String configDnsMore(int count);

  /// No description provided for @configDnsDropped.
  ///
  /// In en, this message translates to:
  /// **'{count} dropped'**
  String configDnsDropped(int count);

  /// No description provided for @configDnsByApp.
  ///
  /// In en, this message translates to:
  /// **'DNS by the app'**
  String get configDnsByApp;

  /// origin is a phrase such as 'from the subscription'
  ///
  /// In en, this message translates to:
  /// **'DNS {origin}'**
  String configDnsOrigin(String origin);

  /// No description provided for @configDnsRefused.
  ///
  /// In en, this message translates to:
  /// **'DNS: {count} refused'**
  String configDnsRefused(int count);

  /// No description provided for @configRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get configRouting;

  /// No description provided for @configRuleSet.
  ///
  /// In en, this message translates to:
  /// **'Rule set'**
  String get configRuleSet;

  /// Name of the built-in rule set
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get configRuleSetDefault;

  /// No description provided for @configRuleLists.
  ///
  /// In en, this message translates to:
  /// **'Rule lists'**
  String get configRuleLists;

  /// No description provided for @ruleSetModeSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get ruleSetModeSplit;

  /// No description provided for @ruleSetModeFull.
  ///
  /// In en, this message translates to:
  /// **'Full tunnel'**
  String get ruleSetModeFull;

  /// No description provided for @ruleSetSummary.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {rules}'**
  String ruleSetSummary(String mode, String rules);

  /// Lowercase chip state: auto-connect has no rules
  ///
  /// In en, this message translates to:
  /// **'no rules'**
  String get ruleSetNoRules;

  /// No description provided for @configNoExceptions.
  ///
  /// In en, this message translates to:
  /// **'no exceptions'**
  String get configNoExceptions;

  /// No description provided for @configRulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String configRulesCount(int count);

  /// No description provided for @configSkippedNotSupported.
  ///
  /// In en, this message translates to:
  /// **'{count} not supported'**
  String configSkippedNotSupported(int count);

  /// No description provided for @configListsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 list unavailable} other{{count} lists unavailable}}'**
  String configListsUnavailable(int count);

  /// No description provided for @configRulesNeedLists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs their lists} other{{count} need their lists}}'**
  String configRulesNeedLists(int count);

  /// No description provided for @configDownloadingLists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Downloading one list…} other{Downloading {count} lists…}}'**
  String configDownloadingLists(int count);

  /// No description provided for @configRuleListsOff.
  ///
  /// In en, this message translates to:
  /// **'Off · {count, plural, =1{1 rule needs them} other{{count} rules need them}}'**
  String configRuleListsOff(int count);

  /// No description provided for @configChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get configChecking;

  /// No description provided for @configNoneDownloadedYet.
  ///
  /// In en, this message translates to:
  /// **'None downloaded yet'**
  String get configNoneDownloadedYet;

  /// No description provided for @configListsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 list} other{{count} lists}}'**
  String configListsCount(int count);

  /// No description provided for @configListsDownloadedOf.
  ///
  /// In en, this message translates to:
  /// **'{have} of {total} downloaded'**
  String configListsDownloadedOf(int have, int total);

  /// No description provided for @configListsSize.
  ///
  /// In en, this message translates to:
  /// **'{count} · {kb} KB'**
  String configListsSize(String count, int kb);

  /// No description provided for @configListsFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One list could not be downloaded} other{{count} lists could not be downloaded}}'**
  String configListsFailedTitle(int count);

  /// No description provided for @configListsFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{names} from {hosts} — the rule using it is not applied.} other{{names} from {hosts} — the rules using them are not applied.}}'**
  String configListsFailedDetail(int count, String names, String hosts);

  /// No description provided for @configReplacedBy.
  ///
  /// In en, this message translates to:
  /// **'Replaced by {name}'**
  String configReplacedBy(String name);

  /// No description provided for @configRoutingOffSummary.
  ///
  /// In en, this message translates to:
  /// **'Off · everything through the VPN'**
  String get configRoutingOffSummary;

  /// No description provided for @configManagedByOrganization.
  ///
  /// In en, this message translates to:
  /// **'Managed by your organization'**
  String get configManagedByOrganization;

  /// No description provided for @configManagedSummary.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {count} rules, set on the server'**
  String configManagedSummary(String mode, int count);

  /// No description provided for @configSetByOrganization.
  ///
  /// In en, this message translates to:
  /// **'{mode} · set by your organization'**
  String configSetByOrganization(String mode);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATION ROUTING'**
  String get configSectionOrganizationRouting;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTION ROUTING'**
  String get configSectionSubscriptionRouting;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'DEVICE ROUTING'**
  String get configSectionDeviceRouting;

  /// No description provided for @configOrganizationRoutingNote.
  ///
  /// In en, this message translates to:
  /// **'Your organization sets this policy and applies it. You can see what it is; changing it is done on their side.'**
  String get configOrganizationRoutingNote;

  /// Fills 'Replaced by {name}'
  ///
  /// In en, this message translates to:
  /// **'the subscription’s routes'**
  String get configSubscriptionRoutes;

  /// No description provided for @configSubscriptionRoutingNote.
  ///
  /// In en, this message translates to:
  /// **'Turn the switch off to use your own rule set instead. Your subscription cannot enforce this either way.'**
  String get configSubscriptionRoutingNote;

  /// No description provided for @configDeviceRoutingNote.
  ///
  /// In en, this message translates to:
  /// **'Rule sets are shared by every configuration; the switch is per configuration, so a work subscription and a personal one can use the same set differently.'**
  String get configDeviceRoutingNote;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get configSectionDetails;

  /// No description provided for @configGetSupport.
  ///
  /// In en, this message translates to:
  /// **'Get support'**
  String get configGetSupport;

  /// No description provided for @configNoPlanDetails.
  ///
  /// In en, this message translates to:
  /// **'Your subscription reported no plan details.'**
  String get configNoPlanDetails;

  /// No description provided for @configUsedNoLimit.
  ///
  /// In en, this message translates to:
  /// **'Used {used} · no limit'**
  String configUsedNoLimit(String used);

  /// No description provided for @configTrafficOf.
  ///
  /// In en, this message translates to:
  /// **'Traffic: {used} of {total}'**
  String configTrafficOf(String used, String total);

  /// No description provided for @configNoExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'No expiry date given'**
  String get configNoExpiryDate;

  /// No description provided for @configExpiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String configExpiredOn(String date);

  /// No description provided for @configActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Active until {date}'**
  String configActiveUntil(String date);

  /// No description provided for @configPlanLine.
  ///
  /// In en, this message translates to:
  /// **'{when} · what the subscription reports, not verified here'**
  String configPlanLine(String when);

  /// No description provided for @configAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get configAccount;

  /// No description provided for @configStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String configStatus(String status);

  /// No description provided for @configStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} · starts on first use'**
  String configStatusOnHold(String status);

  /// No description provided for @configStatusExpires.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} · expires {date}'**
  String configStatusExpires(String status, String date);

  /// No description provided for @configLastRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Last refreshed'**
  String get configLastRefreshed;

  /// No description provided for @configRefreshEvery.
  ///
  /// In en, this message translates to:
  /// **'Refresh every'**
  String get configRefreshEvery;

  /// No description provided for @configHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get configHours;

  /// No description provided for @configRefreshAsSubscriptionAsks.
  ///
  /// In en, this message translates to:
  /// **'As the subscription asks'**
  String get configRefreshAsSubscriptionAsks;

  /// No description provided for @configRefreshEnterWholeHours.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of hours.'**
  String get configRefreshEnterWholeHours;

  /// No description provided for @configRefreshNever.
  ///
  /// In en, this message translates to:
  /// **'never · {every}'**
  String configRefreshNever(String every);

  /// No description provided for @configRefreshAgo.
  ///
  /// In en, this message translates to:
  /// **'{ago} · {every}'**
  String configRefreshAgo(String ago, String every);

  /// No description provided for @configAutoEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'auto every {count} min'**
  String configAutoEveryMinutes(int count);

  /// No description provided for @configAutoEveryHours.
  ///
  /// In en, this message translates to:
  /// **'auto every {count} h'**
  String configAutoEveryHours(int count);

  /// No description provided for @configAutoEveryDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{auto every day} other{auto every {count} days}}'**
  String configAutoEveryDays(int count);

  /// No description provided for @configRefreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get configRefreshNow;

  /// No description provided for @configRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh — {detail}'**
  String configRefreshFailed(String detail);

  /// No description provided for @configRefreshFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'showing the servers we already have.'**
  String get configRefreshFailedFallback;

  /// No description provided for @configOrganizationPolicyDetail.
  ///
  /// In en, this message translates to:
  /// **'These rules are set on the server and cannot be changed here.'**
  String get configOrganizationPolicyDetail;

  /// No description provided for @configSentBy.
  ///
  /// In en, this message translates to:
  /// **'Sent by {name}'**
  String configSentBy(String name);

  /// No description provided for @configProviderPolicyDetail.
  ///
  /// In en, this message translates to:
  /// **'Read-only. Refreshing the subscription replaces them.'**
  String get configProviderPolicyDetail;

  /// No description provided for @configProviderPolicyDetailSkipped.
  ///
  /// In en, this message translates to:
  /// **'Read-only. Refreshing the subscription replaces them. {count, plural, =1{1 more rule could not be translated for this app and is not applied.} other{{count} more rules could not be translated for this app and are not applied.}}'**
  String configProviderPolicyDetailSkipped(int count);

  /// No description provided for @ruleSetSplitTunneling.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling'**
  String get ruleSetSplitTunneling;

  /// No description provided for @ruleSetGeoNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Geo databases not downloaded'**
  String get ruleSetGeoNotDownloaded;

  /// No description provided for @ruleSetGeoNotDownloadedDetail.
  ///
  /// In en, this message translates to:
  /// **'geoip / geosite rules are inactive until then (~25 MB)'**
  String get ruleSetGeoNotDownloadedDetail;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'RULES — FIRST MATCH WINS'**
  String get ruleSetRulesHeader;

  /// No description provided for @homeAddConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Add configuration'**
  String get homeAddConfiguration;

  /// No description provided for @homeConfigurationSettings.
  ///
  /// In en, this message translates to:
  /// **'Configuration settings'**
  String get homeConfigurationSettings;

  /// Status chip: whether the system auto-connects; state is one of homeAutoOff/homeAutoPaused/homeAutoNoRules/homeAutoNotArmed/homeStateOn
  ///
  /// In en, this message translates to:
  /// **'Auto · {state}'**
  String homeChipAuto(String state);

  /// Status chip: the active routing mode
  ///
  /// In en, this message translates to:
  /// **'Routing · {state}'**
  String homeChipRouting(String state);

  /// Status chip: whether logs are collected; state is homeStateOn/homeStateOff
  ///
  /// In en, this message translates to:
  /// **'Logs · {state}'**
  String homeChipLogs(String state);

  /// Lowercase chip state: the feature is on
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get homeStateOn;

  /// Lowercase chip state: the feature is off
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get homeStateOff;

  /// Lowercase chip state: auto-connect is paused
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get homeAutoPaused;

  /// Lowercase chip state: the system has not armed auto-connect yet
  ///
  /// In en, this message translates to:
  /// **'not armed'**
  String get homeAutoNotArmed;

  /// No description provided for @homeCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected, but nothing came back'**
  String get homeCheckFailedTitle;

  /// No description provided for @homeCheckFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'The check found no answer through this server. Try another one, or open Advanced.'**
  String get homeCheckFailedDetail;

  /// No description provided for @homeAutoConnectPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect paused'**
  String get homeAutoConnectPausedTitle;

  /// No description provided for @homeAutoConnectPausedDetail.
  ///
  /// In en, this message translates to:
  /// **'Press Connect to arm it again'**
  String get homeAutoConnectPausedDetail;

  /// No description provided for @homeAutoConnectNotArmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect not armed yet'**
  String get homeAutoConnectNotArmedTitle;

  /// No description provided for @homeAutoConnectNotArmedDetail.
  ///
  /// In en, this message translates to:
  /// **'Connect once so the system can take over'**
  String get homeAutoConnectNotArmedDetail;

  /// No description provided for @homeNoServers.
  ///
  /// In en, this message translates to:
  /// **'No servers'**
  String get homeNoServers;

  /// Location row subtitle for a proxy group: the engine picks the server
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get homeGroupAuto;

  /// Location row subtitle for a proxy group, naming the server the engine picked
  ///
  /// In en, this message translates to:
  /// **'auto · {server}'**
  String homeGroupAutoPicked(String server);

  /// Account line: the account status and its expiry date
  ///
  /// In en, this message translates to:
  /// **'{status} · until {until}'**
  String homeAccountUntil(String status, String until);

  /// No description provided for @homeConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get homeConfiguration;

  /// No description provided for @homeServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get homeServer;

  /// Section header in the server picker above the proxy groups
  ///
  /// In en, this message translates to:
  /// **'CHOSEN BY THE ENGINE'**
  String get homeChosenByEngine;

  /// No description provided for @homeSwitchingServer.
  ///
  /// In en, this message translates to:
  /// **'Switching server…'**
  String get homeSwitchingServer;

  /// No description provided for @homeGettingServer.
  ///
  /// In en, this message translates to:
  /// **'Getting the server…'**
  String get homeGettingServer;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// Status line with the session duration, e.g. 00:12:03
  ///
  /// In en, this message translates to:
  /// **'Connected · {clock}'**
  String homeConnectedClock(String clock);

  /// Status line suffix when the system is auto-connecting
  ///
  /// In en, this message translates to:
  /// **'{status} · auto'**
  String homeStatusAuto(String status);

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusNotConnected;

  /// Proxy group subtitle: what the group does and how often it re-tests its members
  ///
  /// In en, this message translates to:
  /// **'{summary} · rechecks every {minutes} min'**
  String homeGroupRechecks(String summary, int minutes);

  /// No description provided for @startCouldntReadFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read the file'**
  String get startCouldntReadFile;

  /// No description provided for @startCouldntReadFileDetail.
  ///
  /// In en, this message translates to:
  /// **'Try opening it again, or paste its contents.'**
  String get startCouldntReadFileDetail;

  /// No description provided for @startAddConnection.
  ///
  /// In en, this message translates to:
  /// **'Add a connection'**
  String get startAddConnection;

  /// No description provided for @startSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link, subscription or config file'**
  String get startSubtitle;

  /// No description provided for @startLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link or subscription'**
  String get startLinkLabel;

  /// No description provided for @startLinkHint.
  ///
  /// In en, this message translates to:
  /// **'vless://…  or  https://…/sub'**
  String get startLinkHint;

  /// No description provided for @startPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get startPaste;

  /// No description provided for @startClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get startClipboardEmpty;

  /// No description provided for @secretsInFileNotice.
  ///
  /// In en, this message translates to:
  /// **'No keyring on this system — sign-in data is kept in a file only your account can read.'**
  String get secretsInFileNotice;

  /// No description provided for @ruleSetImport.
  ///
  /// In en, this message translates to:
  /// **'Import a rule set'**
  String get ruleSetImport;

  /// No description provided for @ruleSetImportFromFile.
  ///
  /// In en, this message translates to:
  /// **'From a file…'**
  String get ruleSetImportFromFile;

  /// No description provided for @ruleSetImportFromFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anoya, Clash / mihomo, Shadowrocket, Surge, Happ'**
  String get ruleSetImportFromFileSubtitle;

  /// No description provided for @ruleSetImportFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get ruleSetImportFromClipboard;

  /// No description provided for @ruleSetImportFromClipboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A rule set or a happ://routing link'**
  String get ruleSetImportFromClipboardSubtitle;

  /// No description provided for @ruleSetImportScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From another device'**
  String get ruleSetImportScanSubtitle;

  /// No description provided for @ruleSetImportScanHint.
  ///
  /// In en, this message translates to:
  /// **'A rule set from Anoya or a Happ routing profile'**
  String get ruleSetImportScanHint;

  /// No description provided for @ruleSetImportNotARuleSet.
  ///
  /// In en, this message translates to:
  /// **'not a rule set'**
  String get ruleSetImportNotARuleSet;

  /// No description provided for @ruleSetImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read a rule set. Anoya reads its own files, Clash / mihomo and Shadowrocket / Surge rules, and Happ routing profiles.'**
  String get ruleSetImportUnreadable;

  /// No description provided for @ruleSetImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import rule set'**
  String get ruleSetImportTitle;

  /// No description provided for @ruleSetImportSourceAnoya.
  ///
  /// In en, this message translates to:
  /// **'Anoya rule set'**
  String get ruleSetImportSourceAnoya;

  /// No description provided for @ruleSetImportSourceClash.
  ///
  /// In en, this message translates to:
  /// **'Clash / mihomo rules'**
  String get ruleSetImportSourceClash;

  /// No description provided for @ruleSetImportSourceSurge.
  ///
  /// In en, this message translates to:
  /// **'Shadowrocket / Surge rules'**
  String get ruleSetImportSourceSurge;

  /// No description provided for @ruleSetImportSourceHapp.
  ///
  /// In en, this message translates to:
  /// **'Happ routing profile'**
  String get ruleSetImportSourceHapp;

  /// No description provided for @ruleSetImportAsIs.
  ///
  /// In en, this message translates to:
  /// **'Nothing to convert'**
  String get ruleSetImportAsIs;

  /// No description provided for @ruleSetImportMigrated.
  ///
  /// In en, this message translates to:
  /// **'Migrated to an Anoya rule set'**
  String get ruleSetImportMigrated;

  /// Rule count on the import preview
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rules} =1{1 rule} other{{count} rules}}'**
  String ruleSetImportRules(int count);

  /// Rules sent direct, on the import preview
  ///
  /// In en, this message translates to:
  /// **'{count} direct'**
  String ruleSetImportDirect(int count);

  /// Rules sent through the VPN, on the import preview
  ///
  /// In en, this message translates to:
  /// **'{count} via VPN'**
  String ruleSetImportProxy(int count);

  /// Blocked rules, on the import preview
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String ruleSetImportBlock(int count);

  /// No description provided for @ruleSetImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'NOT CARRIED OVER'**
  String get ruleSetImportSkipped;

  /// No description provided for @ruleSetImportSkipDns.
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get ruleSetImportSkipDns;

  /// No description provided for @ruleSetImportSkipDnsDetail.
  ///
  /// In en, this message translates to:
  /// **'Set per configuration in Anoya'**
  String get ruleSetImportSkipDnsDetail;

  /// No description provided for @ruleSetImportSkipGeo.
  ///
  /// In en, this message translates to:
  /// **'Geo database links'**
  String get ruleSetImportSkipGeo;

  /// No description provided for @ruleSetImportSkipGeoDetail.
  ///
  /// In en, this message translates to:
  /// **'Anoya uses its own, in Settings'**
  String get ruleSetImportSkipGeoDetail;

  /// Rules referencing a list by URL that were not imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule with a list by link} other{{count} rules with lists by link}}'**
  String ruleSetImportSkipLists(int count);

  /// No description provided for @ruleSetImportSkipListsDetail.
  ///
  /// In en, this message translates to:
  /// **'Lists by link aren’t part of your own rule sets'**
  String get ruleSetImportSkipListsDetail;

  /// Rules of a type Anoya does not run that were not imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule Anoya can’t run} other{{count} rules Anoya can’t run}}'**
  String ruleSetImportSkipOther(int count);

  /// No description provided for @ruleSetImportAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule set'**
  String get ruleSetImportAdd;

  /// No description provided for @ruleSetImportAdded.
  ///
  /// In en, this message translates to:
  /// **'Rule set “{name}” added'**
  String ruleSetImportAdded(String name);

  /// No description provided for @ruleSetImportDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Imported rule set'**
  String get ruleSetImportDefaultName;

  /// No description provided for @ruleSetExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get ruleSetExport;

  /// No description provided for @ruleSetExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export “{name}”'**
  String ruleSetExportTitle(String name);

  /// No description provided for @ruleSetExportShare.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get ruleSetExportShare;

  /// No description provided for @ruleSetExportShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send the file to another app or device'**
  String get ruleSetExportShareSubtitle;

  /// No description provided for @ruleSetExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save to file…'**
  String get ruleSetExportSave;

  /// No description provided for @ruleSetExportCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get ruleSetExportCopy;

  /// No description provided for @ruleSetExportCopySubtitle.
  ///
  /// In en, this message translates to:
  /// **'As an anoya://ruleset link'**
  String get ruleSetExportCopySubtitle;

  /// No description provided for @ruleSetExportQr.
  ///
  /// In en, this message translates to:
  /// **'Show a QR code'**
  String get ruleSetExportQr;

  /// No description provided for @ruleSetExportQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan it in Anoya on another device'**
  String get ruleSetExportQrSubtitle;

  /// No description provided for @ruleSetExportQrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large for a QR code — share it as a file'**
  String get ruleSetExportQrTooLarge;

  /// No description provided for @ruleSetQrHint.
  ///
  /// In en, this message translates to:
  /// **'In Anoya on the other device: Rule sets → Import → Scan a QR code.'**
  String get ruleSetQrHint;

  /// No description provided for @startScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get startScanQr;

  /// No description provided for @qrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a QR code'**
  String get qrHint;

  /// No description provided for @qrHintDetail.
  ///
  /// In en, this message translates to:
  /// **'A link, a subscription or a subscription key'**
  String get qrHintDetail;

  /// Progress chip while a subscription key shown as several QR codes is being collected
  ///
  /// In en, this message translates to:
  /// **'Subscription key · part {received} of {total} — keep the camera on the code'**
  String qrParts(int received, int total);

  /// No description provided for @qrPartsDetail.
  ///
  /// In en, this message translates to:
  /// **'The app shows the parts one after another'**
  String get qrPartsDetail;

  /// No description provided for @qrStillLooking.
  ///
  /// In en, this message translates to:
  /// **'Still looking — point at another code'**
  String get qrStillLooking;

  /// No description provided for @qrFromPhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose from photos'**
  String get qrFromPhotos;

  /// No description provided for @qrNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No access to the camera'**
  String get qrNoCamera;

  /// No description provided for @qrNoCameraDetail.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in the system settings, or choose a screenshot of the QR code.'**
  String get qrNoCameraDetail;

  /// No description provided for @qrNoCodeInImage.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in this image'**
  String get qrNoCodeInImage;

  /// No description provided for @qrTorch.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get qrTorch;

  /// Chip under the link field explaining why the text cannot be added
  ///
  /// In en, this message translates to:
  /// **'Can’t use this · {reason}'**
  String startCantUseThis(String reason);

  /// No description provided for @startOpenConfigFile.
  ///
  /// In en, this message translates to:
  /// **'Open a config file…'**
  String get startOpenConfigFile;

  /// Divider word between the two ways of adding a connection
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get startOr;

  /// No description provided for @startSignInToServer.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your server'**
  String get startSignInToServer;

  /// No description provided for @startOpenSubscriptionPage.
  ///
  /// In en, this message translates to:
  /// **'Open subscription page'**
  String get startOpenSubscriptionPage;

  /// No description provided for @signInEnterServerFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter the server address first'**
  String get signInEnterServerFirst;

  /// No description provided for @signInNoSsoProviders.
  ///
  /// In en, this message translates to:
  /// **'This server has no SSO providers'**
  String get signInNoSsoProviders;

  /// No description provided for @signInNoSsoProvidersDetail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a username and password instead.'**
  String get signInNoSsoProvidersDetail;

  /// Title of the SSO provider picker
  ///
  /// In en, this message translates to:
  /// **'Sign in with'**
  String get signInWith;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your organization’s or personal server'**
  String get signInSubtitle;

  /// No description provided for @signInServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get signInServerAddress;

  /// No description provided for @signInServerHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-server'**
  String get signInServerHint;

  /// No description provided for @signInUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get signInUsername;

  /// No description provided for @signInPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signInPassword;

  /// No description provided for @signInWithSso.
  ///
  /// In en, this message translates to:
  /// **'Sign in with SSO'**
  String get signInWithSso;

  /// Singular noun for a picker row, used in uiNoMatches
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get uiNounItem;

  /// Singular noun for a picker row, used in uiNoMatches
  ///
  /// In en, this message translates to:
  /// **'server'**
  String get uiNounServer;

  /// Singular noun for a picker row, used in uiNoMatches
  ///
  /// In en, this message translates to:
  /// **'country'**
  String get uiNounCountry;

  /// No description provided for @uiRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get uiRemoveFromFavorites;

  /// No description provided for @uiAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get uiAddToFavorites;

  /// Picker section header while a search matches nothing
  ///
  /// In en, this message translates to:
  /// **'ALL · NOTHING MATCHES'**
  String get uiAllNothingMatches;

  /// Picker section header while searching: how many rows match
  ///
  /// In en, this message translates to:
  /// **'ALL · {shown} OF {total} MATCH'**
  String uiAllMatchCount(int shown, int total);

  /// Picker empty state; noun is one of the uiNoun* keys
  ///
  /// In en, this message translates to:
  /// **'No {noun} matches “{query}”. Clear the search to see all {total}.'**
  String uiNoMatches(String noun, String query, int total);

  /// No description provided for @ruleSetModeFullDescription.
  ///
  /// In en, this message translates to:
  /// **'All traffic goes through the VPN; rules define exceptions.'**
  String get ruleSetModeFullDescription;

  /// No description provided for @ruleSetModeSplitDescription.
  ///
  /// In en, this message translates to:
  /// **'Only traffic matching the rules goes through the VPN; the rest connects directly.'**
  String get ruleSetModeSplitDescription;

  /// No description provided for @ruleSetNoRulesSplit.
  ///
  /// In en, this message translates to:
  /// **'No rules: no traffic goes through the VPN. Add rules for what should be tunneled.'**
  String get ruleSetNoRulesSplit;

  /// No description provided for @ruleSetNoRulesFull.
  ///
  /// In en, this message translates to:
  /// **'No rules: all traffic goes through the VPN.'**
  String get ruleSetNoRulesFull;

  /// No description provided for @ruleSetDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get ruleSetDownload;

  /// Rule row subtitle: the rule matches a downloaded rule list
  ///
  /// In en, this message translates to:
  /// **'rule list'**
  String get ruleKindRuleList;

  /// No description provided for @ruleInactiveNoDatabase.
  ///
  /// In en, this message translates to:
  /// **'{kind} · inactive — no database'**
  String ruleInactiveNoDatabase(String kind);

  /// No description provided for @ruleInactiveDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'{kind} · inactive — desktop only'**
  String ruleInactiveDesktopOnly(String kind);

  /// No description provided for @ruleInactiveListsOff.
  ///
  /// In en, this message translates to:
  /// **'{kind} · inactive — lists are off'**
  String ruleInactiveListsOff(String kind);

  /// No description provided for @ruleInactiveNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{kind} · inactive — not downloaded'**
  String ruleInactiveNotDownloaded(String kind);

  /// No description provided for @ruleNoResolveKind.
  ///
  /// In en, this message translates to:
  /// **'{kind} · no-resolve'**
  String ruleNoResolveKind(String kind);

  /// No description provided for @ruleTypeDomainSuffix.
  ///
  /// In en, this message translates to:
  /// **'domain and subdomains'**
  String get ruleTypeDomainSuffix;

  /// No description provided for @ruleTypeDomainKeyword.
  ///
  /// In en, this message translates to:
  /// **'domain contains'**
  String get ruleTypeDomainKeyword;

  /// No description provided for @ruleTypeDomainExact.
  ///
  /// In en, this message translates to:
  /// **'exact domain'**
  String get ruleTypeDomainExact;

  /// No description provided for @ruleTypeIpCidr.
  ///
  /// In en, this message translates to:
  /// **'IP range'**
  String get ruleTypeIpCidr;

  /// No description provided for @ruleTypeProcessName.
  ///
  /// In en, this message translates to:
  /// **'app by name'**
  String get ruleTypeProcessName;

  /// No description provided for @ruleTypeGeoip.
  ///
  /// In en, this message translates to:
  /// **'country by IP'**
  String get ruleTypeGeoip;

  /// No description provided for @ruleTypeGeosite.
  ///
  /// In en, this message translates to:
  /// **'domain lists'**
  String get ruleTypeGeosite;

  /// No description provided for @ruleTypeDomainRegex.
  ///
  /// In en, this message translates to:
  /// **'domain matches a pattern'**
  String get ruleTypeDomainRegex;

  /// No description provided for @ruleTypeRuleList.
  ///
  /// In en, this message translates to:
  /// **'a list from your subscription'**
  String get ruleTypeRuleList;

  /// No description provided for @rulePickCountry.
  ///
  /// In en, this message translates to:
  /// **'Pick a country.'**
  String get rulePickCountry;

  /// No description provided for @ruleInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid value for {type}.'**
  String ruleInvalidValue(String type);

  /// Label of the rule's match-type field
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get ruleMatch;

  /// No description provided for @ruleNotAvailableOnPlatform.
  ///
  /// In en, this message translates to:
  /// **'not available on this platform'**
  String get ruleNotAvailableOnPlatform;

  /// No description provided for @ruleNeedsGeoDatabases.
  ///
  /// In en, this message translates to:
  /// **'needs geo databases'**
  String get ruleNeedsGeoDatabases;

  /// No description provided for @ruleAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get ruleAction;

  /// No description provided for @ruleActionProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'through the VPN'**
  String get ruleActionProxyDescription;

  /// No description provided for @ruleActionDirectDescription.
  ///
  /// In en, this message translates to:
  /// **'bypass the VPN'**
  String get ruleActionDirectDescription;

  /// No description provided for @ruleActionBlockDescription.
  ///
  /// In en, this message translates to:
  /// **'drop the connection'**
  String get ruleActionBlockDescription;

  /// No description provided for @ruleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get ruleAdd;

  /// No description provided for @ruleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get ruleEdit;

  /// No description provided for @ruleCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get ruleCountry;

  /// No description provided for @ruleChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get ruleChoose;

  /// No description provided for @ruleNoResolveDescription.
  ///
  /// In en, this message translates to:
  /// **'Match only plain-IP connections, don’t resolve domains'**
  String get ruleNoResolveDescription;

  /// No description provided for @ruleValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get ruleValue;

  /// No description provided for @ruleSummaryGeoip.
  ///
  /// In en, this message translates to:
  /// **'traffic to IPs in {country}'**
  String ruleSummaryGeoip(String country);

  /// No description provided for @ruleSummaryGeosite.
  ///
  /// In en, this message translates to:
  /// **'\"{category}\" domains (GeoSite list)'**
  String ruleSummaryGeosite(String category);

  /// No description provided for @ruleSummaryProcess.
  ///
  /// In en, this message translates to:
  /// **'traffic of \"{name}\"'**
  String ruleSummaryProcess(String name);

  /// No description provided for @ruleSummaryMatching.
  ///
  /// In en, this message translates to:
  /// **'traffic matching {value}'**
  String ruleSummaryMatching(String value);

  /// No description provided for @ruleSummaryProxy.
  ///
  /// In en, this message translates to:
  /// **'goes through the VPN'**
  String get ruleSummaryProxy;

  /// No description provided for @ruleSummaryDirect.
  ///
  /// In en, this message translates to:
  /// **'connects directly, bypassing the VPN'**
  String get ruleSummaryDirect;

  /// No description provided for @ruleSummaryBlock.
  ///
  /// In en, this message translates to:
  /// **'is blocked'**
  String get ruleSummaryBlock;

  /// Preview of what a rule does: target is a ruleSummaryGeoip/Geosite/Process/Matching phrase, verb a ruleSummaryProxy/Direct/Block phrase
  ///
  /// In en, this message translates to:
  /// **'→ {target} {verb}.'**
  String ruleSummary(String target, String verb);

  /// No description provided for @ruleSetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String ruleSetDeleteTitle(String name);

  /// No description provided for @ruleSetDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Configurations using this set fall back to Default.'**
  String get ruleSetDeleteBody;

  /// No description provided for @ruleSetDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete rule set'**
  String get ruleSetDeleteTooltip;

  /// No description provided for @ruleSetSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get ruleSetSimple;

  /// No description provided for @ruleSetDownloadSiteLists.
  ///
  /// In en, this message translates to:
  /// **'Download the site lists first'**
  String get ruleSetDownloadSiteLists;

  /// No description provided for @ruleSetDownloadSiteListsDetail.
  ///
  /// In en, this message translates to:
  /// **'Picking services needs the geo databases (~25 MB, one time)'**
  String get ruleSetDownloadSiteListsDetail;

  /// No description provided for @ruleSetAdvancedRules.
  ///
  /// In en, this message translates to:
  /// **'Advanced rules · {count}'**
  String ruleSetAdvancedRules(int count);

  /// No description provided for @ruleSetAdvancedRulesDetail.
  ///
  /// In en, this message translates to:
  /// **'Apply before the list below · edit in Advanced'**
  String get ruleSetAdvancedRulesDetail;

  /// No description provided for @ruleSetSearchServices.
  ///
  /// In en, this message translates to:
  /// **'Search services'**
  String get ruleSetSearchServices;

  /// No description provided for @ruleSetCountriesHeader.
  ///
  /// In en, this message translates to:
  /// **'COUNTRIES'**
  String get ruleSetCountriesHeader;

  /// No description provided for @ruleSetAddCountry.
  ///
  /// In en, this message translates to:
  /// **'Add country'**
  String get ruleSetAddCountry;

  /// No description provided for @ruleSetServicesHeader.
  ///
  /// In en, this message translates to:
  /// **'SERVICES'**
  String get ruleSetServicesHeader;

  /// No description provided for @ruleSetAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get ruleSetAddCategory;

  /// No description provided for @ruleSetOtherCategoriesHeader.
  ///
  /// In en, this message translates to:
  /// **'OTHER CATEGORIES'**
  String get ruleSetOtherCategoriesHeader;

  /// No description provided for @ruleSetNothingSelectedSplit.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected · no traffic goes through the VPN yet'**
  String get ruleSetNothingSelectedSplit;

  /// No description provided for @ruleSetNothingSelectedFull.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected · everything goes through the VPN'**
  String get ruleSetNothingSelectedFull;

  /// No description provided for @ruleSetSelectedSplit.
  ///
  /// In en, this message translates to:
  /// **'{count} selected · everything else connects directly'**
  String ruleSetSelectedSplit(int count);

  /// No description provided for @ruleSetSelectedFull.
  ///
  /// In en, this message translates to:
  /// **'{count} selected · they connect directly, the rest goes through the VPN'**
  String ruleSetSelectedFull(int count);

  /// No description provided for @ruleSetOnlySelected.
  ///
  /// In en, this message translates to:
  /// **'Only selected'**
  String get ruleSetOnlySelected;

  /// No description provided for @ruleSetAllExceptSelected.
  ///
  /// In en, this message translates to:
  /// **'All except selected'**
  String get ruleSetAllExceptSelected;

  /// No description provided for @ruleSetOnlySelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the services you pick go through the VPN. Everything else connects directly.'**
  String get ruleSetOnlySelectedDescription;

  /// No description provided for @ruleSetAllExceptSelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything goes through the VPN. The services you pick connect directly.'**
  String get ruleSetAllExceptSelectedDescription;

  /// No description provided for @ruleSetNew.
  ///
  /// In en, this message translates to:
  /// **'New rule set'**
  String get ruleSetNew;

  /// Example name in the new-rule-set prompt
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get ruleSetNameHint;

  /// No description provided for @ruleSetCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get ruleSetCreate;

  /// No description provided for @ruleSetRuleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no rules} other{{count} rules}}'**
  String ruleSetRuleCount(int count);

  /// No description provided for @ruleSetUsedBy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{used by 1 config} other{used by {count} configs}}'**
  String ruleSetUsedBy(int count);

  /// Rule set row subtitle with how many configurations use it
  ///
  /// In en, this message translates to:
  /// **'{mode} · {rules} · {used}'**
  String ruleSetSummaryUsed(String mode, String rules, String used);

  /// No description provided for @onDemandEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable on demand'**
  String get onDemandEnable;

  /// No description provided for @onDemandEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The system applies the first matching rule'**
  String get onDemandEnableSubtitle;

  /// No description provided for @onDemandNoRules.
  ///
  /// In en, this message translates to:
  /// **'No rules. Enabling on demand adds “Connect · Any network”.'**
  String get onDemandNoRules;

  /// No description provided for @onDemandRulesFootnote.
  ///
  /// In en, this message translates to:
  /// **'Rules are evaluated top to bottom. If none matches, the tunnel is left as is.'**
  String get onDemandRulesFootnote;

  /// Short tag in a rule row for the Connect action
  ///
  /// In en, this message translates to:
  /// **'CONN.'**
  String get onDemandTagConnect;

  /// Short tag in a rule row for the Disconnect action
  ///
  /// In en, this message translates to:
  /// **'DISC.'**
  String get onDemandTagDisconnect;

  /// Short tag in a rule row for the Ignore action
  ///
  /// In en, this message translates to:
  /// **'IGNORE'**
  String get onDemandTagIgnore;

  /// No description provided for @onDemandNewRule.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get onDemandNewRule;

  /// No description provided for @onDemandActionIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get onDemandActionIgnore;

  /// No description provided for @onDemandActionConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'bring the tunnel up'**
  String get onDemandActionConnectSubtitle;

  /// No description provided for @onDemandActionDisconnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'tear the tunnel down'**
  String get onDemandActionDisconnectSubtitle;

  /// No description provided for @onDemandActionIgnoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'leave the tunnel as is'**
  String get onDemandActionIgnoreSubtitle;

  /// Network segment / empty condition list: matches any network or value
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get onDemandAny;

  /// No description provided for @onDemandNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get onDemandNameOptional;

  /// No description provided for @onDemandNameHint.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get onDemandNameHint;

  /// No description provided for @onDemandNetworkHeader.
  ///
  /// In en, this message translates to:
  /// **'NETWORK'**
  String get onDemandNetworkHeader;

  /// No description provided for @onDemandNetworkHelpAny.
  ///
  /// In en, this message translates to:
  /// **'The rule is checked on every network — Wi-Fi, mobile or wired.'**
  String get onDemandNetworkHelpAny;

  /// No description provided for @onDemandNetworkHelpWifi.
  ///
  /// In en, this message translates to:
  /// **'When the device joins a Wi-Fi network, the system checks the conditions below and applies the rule.'**
  String get onDemandNetworkHelpWifi;

  /// No description provided for @onDemandNetworkHelpCellular.
  ///
  /// In en, this message translates to:
  /// **'When the device is on mobile data, the system checks the conditions below and applies the rule.'**
  String get onDemandNetworkHelpCellular;

  /// No description provided for @onDemandNetworkHelpEthernet.
  ///
  /// In en, this message translates to:
  /// **'When the device is on a wired network, the system checks the conditions below and applies the rule.'**
  String get onDemandNetworkHelpEthernet;

  /// No description provided for @onDemandConditionsHeader.
  ///
  /// In en, this message translates to:
  /// **'CONDITIONS'**
  String get onDemandConditionsHeader;

  /// No description provided for @onDemandWifiNetworks.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi networks'**
  String get onDemandWifiNetworks;

  /// No description provided for @onDemandWifiNetwork.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi network'**
  String get onDemandWifiNetwork;

  /// Unit word in the header '3 NETWORKS · ANY OF THEM MATCHES'
  ///
  /// In en, this message translates to:
  /// **'NETWORKS'**
  String get onDemandNetworksUnit;

  /// No description provided for @onDemandWifiNetworksHelp.
  ///
  /// In en, this message translates to:
  /// **'Matches the network name exactly. Leave empty for any Wi-Fi.'**
  String get onDemandWifiNetworksHelp;

  /// No description provided for @onDemandDnsDomains.
  ///
  /// In en, this message translates to:
  /// **'DNS search domains'**
  String get onDemandDnsDomains;

  /// No description provided for @onDemandDnsDomain.
  ///
  /// In en, this message translates to:
  /// **'DNS search domain'**
  String get onDemandDnsDomain;

  /// Unit word in the header '3 DOMAINS · ANY OF THEM MATCHES'
  ///
  /// In en, this message translates to:
  /// **'DOMAINS'**
  String get onDemandDomainsUnit;

  /// No description provided for @onDemandDnsDomainsHelp.
  ///
  /// In en, this message translates to:
  /// **'Matches when the network’s search domain ends with an entry.'**
  String get onDemandDnsDomainsHelp;

  /// No description provided for @onDemandDnsServers.
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get onDemandDnsServers;

  /// No description provided for @onDemandDnsServer.
  ///
  /// In en, this message translates to:
  /// **'DNS server'**
  String get onDemandDnsServer;

  /// Unit word in the header '3 SERVERS · ANY OF THEM MATCHES'
  ///
  /// In en, this message translates to:
  /// **'SERVERS'**
  String get onDemandServersUnit;

  /// No description provided for @onDemandDnsServersHelp.
  ///
  /// In en, this message translates to:
  /// **'Matches the network’s DNS servers; a single “*” wildcard is allowed.'**
  String get onDemandDnsServersHelp;

  /// No description provided for @onDemandUrlProbeHeader.
  ///
  /// In en, this message translates to:
  /// **'URL PROBE'**
  String get onDemandUrlProbeHeader;

  /// No description provided for @onDemandUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'URL (optional)'**
  String get onDemandUrlOptional;

  /// No description provided for @onDemandUrlProbeHelp.
  ///
  /// In en, this message translates to:
  /// **'The rule matches only if this URL returns 200 without redirects.'**
  String get onDemandUrlProbeHelp;

  /// No description provided for @onDemandNoEntries.
  ///
  /// In en, this message translates to:
  /// **'NO ENTRIES'**
  String get onDemandNoEntries;

  /// Section header of a condition list; unit is one of the *Unit strings (NETWORKS, DOMAINS, SERVERS)
  ///
  /// In en, this message translates to:
  /// **'{count} {unit} · ANY OF THEM MATCHES'**
  String onDemandEntriesHeader(int count, String unit);

  /// No description provided for @onDemandConditionIgnored.
  ///
  /// In en, this message translates to:
  /// **'The condition is ignored and the rule matches any network of the selected type.'**
  String get onDemandConditionIgnored;

  /// No description provided for @onDemandInterfaceAny.
  ///
  /// In en, this message translates to:
  /// **'Any network'**
  String get onDemandInterfaceAny;

  /// No description provided for @onDemandInterfaceWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get onDemandInterfaceWifi;

  /// No description provided for @onDemandInterfaceCellular.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get onDemandInterfaceCellular;

  /// No description provided for @onDemandInterfaceEthernet.
  ///
  /// In en, this message translates to:
  /// **'Ethernet'**
  String get onDemandInterfaceEthernet;

  /// No description provided for @onDemandSummarySsid.
  ///
  /// In en, this message translates to:
  /// **'SSID {values}'**
  String onDemandSummarySsid(String values);

  /// No description provided for @onDemandSummaryDomain.
  ///
  /// In en, this message translates to:
  /// **'domain {values}'**
  String onDemandSummaryDomain(String values);

  /// No description provided for @onDemandSummaryDns.
  ///
  /// In en, this message translates to:
  /// **'DNS {values}'**
  String onDemandSummaryDns(String values);

  /// Rule summary part: the rule has a URL probe condition
  ///
  /// In en, this message translates to:
  /// **'probe'**
  String get onDemandSummaryProbe;

  /// No description provided for @onDemandStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get onDemandStatusPaused;

  /// No description provided for @onDemandStatusAwaitingFirstConnect.
  ///
  /// In en, this message translates to:
  /// **'On · after first connect'**
  String get onDemandStatusAwaitingFirstConnect;

  /// No description provided for @onDemandStatusOnRules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{On · 1 rule} other{On · {count} rules}}'**
  String onDemandStatusOnRules(int count);

  /// Name of the rule seeded when on demand is enabled with an empty list
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get onDemandDefaultRuleName;

  /// No description provided for @statusNoConfiguration.
  ///
  /// In en, this message translates to:
  /// **'No configuration'**
  String get statusNoConfiguration;

  /// No description provided for @menuBarSwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching…'**
  String get menuBarSwitching;

  /// No description provided for @profilesCouldntGetServer.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t get the server for {label}'**
  String profilesCouldntGetServer(String label);

  /// No description provided for @profilesPreviousServerStillInUse.
  ///
  /// In en, this message translates to:
  /// **'The previous one is still in use.'**
  String get profilesPreviousServerStillInUse;

  /// No description provided for @profilesCouldntSwitch.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t switch'**
  String get profilesCouldntSwitch;

  /// No description provided for @profilesCouldntSwitchDetail.
  ///
  /// In en, this message translates to:
  /// **'The tunnel kept the previous configuration. Try again, or reconnect.'**
  String get profilesCouldntSwitchDetail;

  /// No description provided for @profilesNoConfigurationDetail.
  ///
  /// In en, this message translates to:
  /// **'Add a link, a subscription, or sign in to your server.'**
  String get profilesNoConfigurationDetail;

  /// No description provided for @profilesNoServers.
  ///
  /// In en, this message translates to:
  /// **'This configuration has no servers'**
  String get profilesNoServers;

  /// No description provided for @profilesNoServersDetail.
  ///
  /// In en, this message translates to:
  /// **'Refresh it, or add another configuration.'**
  String get profilesNoServersDetail;

  /// No description provided for @profilesTunnelStopped.
  ///
  /// In en, this message translates to:
  /// **'The tunnel stopped'**
  String get profilesTunnelStopped;

  /// No description provided for @connectionCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The server did not answer in time.'**
  String get connectionCheckTimedOut;

  /// No description provided for @connectionCheckClosed.
  ///
  /// In en, this message translates to:
  /// **'The server closed the connection.'**
  String get connectionCheckClosed;

  /// No description provided for @connectionCheckRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused the connection.'**
  String get connectionCheckRefused;

  /// No description provided for @connectionCheckNoServer.
  ///
  /// In en, this message translates to:
  /// **'There is no server to test — the tunnel is running something else.'**
  String get connectionCheckNoServer;

  /// No description provided for @connectionCheckTunnelNotRunning.
  ///
  /// In en, this message translates to:
  /// **'The tunnel is not running.'**
  String get connectionCheckTunnelNotRunning;

  /// No description provided for @connectionCheckNothingCameBack.
  ///
  /// In en, this message translates to:
  /// **'Nothing came back.'**
  String get connectionCheckNothingCameBack;

  /// No description provided for @connectionCheckEngineDidNotAnswer.
  ///
  /// In en, this message translates to:
  /// **'The engine did not answer.'**
  String get connectionCheckEngineDidNotAnswer;

  /// No description provided for @errorDeviceLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Device limit reached'**
  String get errorDeviceLimitTitle;

  /// No description provided for @errorDeviceLimitDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription’s device limit is full, so it sent a placeholder instead of your servers. Free a slot in your subscription, then refresh.'**
  String get errorDeviceLimitDetail;

  /// No description provided for @errorUnreadableSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read this subscription'**
  String get errorUnreadableSubscriptionTitle;

  /// No description provided for @errorUnreadableSubscriptionDetail.
  ///
  /// In en, this message translates to:
  /// **'Your subscription sent a format this app does not recognise. It reads base64 link lists, Clash / mihomo, Xray JSON and sing-box. Nothing was added.'**
  String get errorUnreadableSubscriptionDetail;

  /// No description provided for @errorEmptySubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'This subscription has no servers'**
  String get errorEmptySubscriptionTitle;

  /// {what} is one of the importFormat* phrases, e.g. 'a Clash / mihomo subscription'
  ///
  /// In en, this message translates to:
  /// **'Your subscription answered with {what} that lists none. That usually means the account is out of days or its device limit is full — ask them.'**
  String errorEmptySubscriptionDetail(String what);

  /// No description provided for @errorNoRunnableServersTitle.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{The only server here cannot run} other{None of the {total} servers can run here}}'**
  String errorNoRunnableServersTitle(int total);

  /// No description provided for @errorNoRunnableServersDetail.
  ///
  /// In en, this message translates to:
  /// **'They use {kinds}, which this app cannot run yet. Nothing was added.'**
  String errorNoRunnableServersDetail(String kinds);

  /// No description provided for @errorProviderMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your subscription sent a message'**
  String get errorProviderMessageTitle;

  /// No description provided for @errorProviderMessageDetail.
  ///
  /// In en, this message translates to:
  /// **'{lines}\n\nNot servers: every entry points nowhere, so nothing was added.'**
  String errorProviderMessageDetail(String lines);

  /// Stands in for the host name in sentences like 'Couldn’t reach {what}' when none is known
  ///
  /// In en, this message translates to:
  /// **'the server'**
  String get errorSubjectDefault;

  /// No description provided for @errorServerDidNotAnswerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server didn’t answer'**
  String get errorServerDidNotAnswerTitle;

  /// No description provided for @errorCouldNotReachDetail.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach {what}. Check your network, or pick another server.'**
  String errorCouldNotReachDetail(String what);

  /// No description provided for @errorSecureConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t set up a secure connection'**
  String get errorSecureConnectionTitle;

  /// No description provided for @errorCertificateRejectedDetail.
  ///
  /// In en, this message translates to:
  /// **'The certificate of {what} was rejected. If the address is right, the server may be misconfigured.'**
  String errorCertificateRejectedDetail(String what);

  /// No description provided for @errorConnectionClosedDetail.
  ///
  /// In en, this message translates to:
  /// **'The connection to {what} was closed.'**
  String errorConnectionClosedDetail(String what);

  /// No description provided for @errorWrongCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password'**
  String get errorWrongCredentialsTitle;

  /// No description provided for @errorWrongCredentialsDetail.
  ///
  /// In en, this message translates to:
  /// **'Check both and try again.'**
  String get errorWrongCredentialsDetail;

  /// No description provided for @errorSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get errorSessionExpiredTitle;

  /// No description provided for @errorSessionExpiredDetail.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {what} again.'**
  String errorSessionExpiredDetail(String what);

  /// No description provided for @errorAccessBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access is blocked'**
  String get errorAccessBlockedTitle;

  /// No description provided for @errorAccessBlockedDetail.
  ///
  /// In en, this message translates to:
  /// **'The server refused this account.'**
  String get errorAccessBlockedDetail;

  /// No description provided for @errorNothingAtAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing at this address'**
  String get errorNothingAtAddressTitle;

  /// No description provided for @errorNothingAtAddressDetail.
  ///
  /// In en, this message translates to:
  /// **'Check the link — {what} has no configuration for this account.'**
  String errorNothingAtAddressDetail(String what);

  /// No description provided for @errorServerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error'**
  String get errorServerErrorTitle;

  /// No description provided for @errorServerErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Nothing to fix on this side — try again in a few minutes.'**
  String get errorServerErrorDetail;

  /// No description provided for @errorServerRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'The server refused the request'**
  String get errorServerRefusedTitle;

  /// No description provided for @errorNotALinkTitle.
  ///
  /// In en, this message translates to:
  /// **'This doesn’t look like a link we know'**
  String get errorNotALinkTitle;

  /// No description provided for @errorNotALinkDetail.
  ///
  /// In en, this message translates to:
  /// **'Expected vless://, vmess://, trojan://, ss:// or a subscription URL.'**
  String get errorNotALinkDetail;

  /// No description provided for @errorTunnelServiceNotRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'The tunnel service isn’t running'**
  String get errorTunnelServiceNotRunningTitle;

  /// No description provided for @errorTunnelServiceNotRunningDetail.
  ///
  /// In en, this message translates to:
  /// **'Anoya installs it as the “AnoyaTunnel” Windows service. Reinstall the app, or start the service in Services, then connect again.'**
  String get errorTunnelServiceNotRunningDetail;

  /// The Linux counterpart of errorTunnelServiceNotRunningDetail; the service is a systemd unit.
  ///
  /// In en, this message translates to:
  /// **'Anoya installs it as the “anoya-tunnel” systemd service. Reinstall the package, or run “sudo systemctl start anoya-tunnel”, then connect again.'**
  String get errorTunnelServiceNotRunningDetailLinux;

  /// No description provided for @errorTunnelServiceStoppedTitle.
  ///
  /// In en, this message translates to:
  /// **'The tunnel service stopped'**
  String get errorTunnelServiceStoppedTitle;

  /// No description provided for @errorTunnelServiceStoppedDetail.
  ///
  /// In en, this message translates to:
  /// **'It restarts on its own within a few seconds — connect again. If this keeps happening, the tunnel log in Settings → Logs says why.'**
  String get errorTunnelServiceStoppedDetail;

  /// No description provided for @errorSystemRefusedTunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'The system refused to start the tunnel'**
  String get errorSystemRefusedTunnelTitle;

  /// No description provided for @errorSystemRefusedTunnelDetail.
  ///
  /// In en, this message translates to:
  /// **'Allow the VPN profile in system settings, then connect again.'**
  String get errorSystemRefusedTunnelDetail;

  /// No description provided for @errorSignInNotFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn’t finish'**
  String get errorSignInNotFinishedTitle;

  /// No description provided for @errorSignInNotFinishedDetail.
  ///
  /// In en, this message translates to:
  /// **'The browser window was closed or the provider refused.'**
  String get errorSignInNotFinishedDetail;

  /// No description provided for @errorSomethingWentWrongTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrongTitle;

  /// No description provided for @errorSomethingWentWrongDetail.
  ///
  /// In en, this message translates to:
  /// **'The details are in Settings → Logs.'**
  String get errorSomethingWentWrongDetail;

  /// No description provided for @errorDeviceNotAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your subscription did not accept this device'**
  String get errorDeviceNotAcceptedTitle;

  /// No description provided for @errorDeviceNotAcceptedDetail.
  ///
  /// In en, this message translates to:
  /// **'It requires a device id this app did send. Ask your subscription’s support.'**
  String get errorDeviceNotAcceptedDetail;

  /// No description provided for @errorApiTimeout.
  ///
  /// In en, this message translates to:
  /// **'No answer from {baseUrl} — check the address and the network.'**
  String errorApiTimeout(String baseUrl);

  /// No description provided for @errorApiNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach {baseUrl} — check the address/port and that the server is up.'**
  String errorApiNetwork(String baseUrl);

  /// No description provided for @errorApiTls.
  ///
  /// In en, this message translates to:
  /// **'TLS error talking to {baseUrl}. If the server runs plain HTTP, enter the address with \"http://\".'**
  String errorApiTls(String baseUrl);

  /// No description provided for @errorApiRequest.
  ///
  /// In en, this message translates to:
  /// **'The request to {baseUrl} could not be completed — check the address and try again.'**
  String errorApiRequest(String baseUrl);

  /// No description provided for @accountExpiredDetail.
  ///
  /// In en, this message translates to:
  /// **'Renew it in your account, then connect again.'**
  String get accountExpiredDetail;

  /// No description provided for @accountLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic limit reached'**
  String get accountLimitedTitle;

  /// No description provided for @accountLimitedDetail.
  ///
  /// In en, this message translates to:
  /// **'The plan is used up until it renews.'**
  String get accountLimitedDetail;

  /// No description provided for @accountDeactivatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access disabled'**
  String get accountDeactivatedTitle;

  /// No description provided for @accountDeactivatedDetail.
  ///
  /// In en, this message translates to:
  /// **'The administrator turned this account off.'**
  String get accountDeactivatedDetail;

  /// No description provided for @accountOnHoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription not started'**
  String get accountOnHoldTitle;

  /// No description provided for @accountOnHoldDetail.
  ///
  /// In en, this message translates to:
  /// **'It begins on the first connection — try again in a moment.'**
  String get accountOnHoldDetail;

  /// {state} is an account status the app does not know, with underscores turned into spaces
  ///
  /// In en, this message translates to:
  /// **'Account is {state}'**
  String accountOtherStateTitle(String state);

  /// No description provided for @accountOtherStateDetail.
  ///
  /// In en, this message translates to:
  /// **'Connecting is not allowed in this state.'**
  String get accountOtherStateDetail;

  /// No description provided for @amneziaErrorEmptyAnswerTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway sent nothing'**
  String get amneziaErrorEmptyAnswerTitle;

  /// No description provided for @amneziaErrorEmptyAnswerDetail.
  ///
  /// In en, this message translates to:
  /// **'It answered without a configuration. Try again; if it repeats, support for this subscription will need to look.'**
  String get amneziaErrorEmptyAnswerDetail;

  /// No description provided for @amneziaErrorCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Took too long'**
  String get amneziaErrorCancelledTitle;

  /// No description provided for @amneziaErrorCancelledDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway did not answer in time. Check the connection and try again.'**
  String get amneziaErrorCancelledDetail;

  /// No description provided for @amneziaErrorNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the gateway'**
  String get amneziaErrorNetworkTitle;

  /// No description provided for @amneziaErrorNetworkDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway did not answer. This is usually the network, not the subscription — try again in a moment.'**
  String get amneziaErrorNetworkDetail;

  /// No description provided for @amneziaErrorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway timed out'**
  String get amneziaErrorTimeoutTitle;

  /// No description provided for @amneziaErrorTimeoutDetail.
  ///
  /// In en, this message translates to:
  /// **'No answer within the time allowed. Check the connection and try again.'**
  String get amneziaErrorTimeoutDetail;

  /// No description provided for @amneziaErrorSslTitle.
  ///
  /// In en, this message translates to:
  /// **'The connection was not trusted'**
  String get amneziaErrorSslTitle;

  /// No description provided for @amneziaErrorSslDetail.
  ///
  /// In en, this message translates to:
  /// **'Something interfered with the secure connection to the gateway.'**
  String get amneziaErrorSslDetail;

  /// No description provided for @amneziaErrorConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'This build cannot talk to the gateway'**
  String get amneziaErrorConfigTitle;

  /// No description provided for @amneziaErrorConfigDetail.
  ///
  /// In en, this message translates to:
  /// **'It was built without the gateway credentials, so subscriptions of this kind are unavailable in it.'**
  String get amneziaErrorConfigDetail;

  /// No description provided for @amneziaErrorDecryptTitle.
  ///
  /// In en, this message translates to:
  /// **'The answer could not be read'**
  String get amneziaErrorDecryptTitle;

  /// No description provided for @amneziaErrorDecryptDetail.
  ///
  /// In en, this message translates to:
  /// **'The reply was not what the gateway should have sent — often a network that intercepts traffic.'**
  String get amneziaErrorDecryptDetail;

  /// No description provided for @amneziaErrorInvalidArgumentTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway request was malformed'**
  String get amneziaErrorInvalidArgumentTitle;

  /// No description provided for @amneziaErrorInvalidArgumentDetail.
  ///
  /// In en, this message translates to:
  /// **'A defect in this app, not in the subscription. Restarting the app helps; if it repeats, the log in Settings → Logs is what support needs.'**
  String get amneziaErrorInvalidArgumentDetail;

  /// No description provided for @amneziaErrorRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway refused the request'**
  String get amneziaErrorRefusedTitle;

  /// No description provided for @amneziaErrorRefusedCodeDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway answered with code {code}.'**
  String amneziaErrorRefusedCodeDetail(int code);

  /// No description provided for @amneziaErrorRefusedHttpDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway answered with HTTP {status}.'**
  String amneziaErrorRefusedHttpDetail(int status);

  /// No description provided for @amneziaErrorTooManyRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many requests'**
  String get amneziaErrorTooManyRequestsTitle;

  /// No description provided for @amneziaErrorTooManyRequestsDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway is throttling this subscription. Wait a few minutes before trying again.'**
  String get amneziaErrorTooManyRequestsDetail;

  /// No description provided for @amneziaErrorTrialUsedTitle.
  ///
  /// In en, this message translates to:
  /// **'Trial already used'**
  String get amneziaErrorTrialUsedTitle;

  /// No description provided for @amneziaErrorTrialUsedDetail.
  ///
  /// In en, this message translates to:
  /// **'This address has already activated a trial.'**
  String get amneziaErrorTrialUsedDetail;

  /// No description provided for @amneziaErrorDeviceLimitDetail.
  ///
  /// In en, this message translates to:
  /// **'This subscription is already installed on as many devices as it allows. Remove one from the subscription, then try again.'**
  String get amneziaErrorDeviceLimitDetail;

  /// No description provided for @amneziaErrorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription not found'**
  String get amneziaErrorNotFoundTitle;

  /// No description provided for @amneziaErrorNotFoundDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway does not recognise this key. Check that it was pasted whole.'**
  String get amneziaErrorNotFoundDetail;

  /// No description provided for @amneziaErrorNewerClientTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway requires a newer client'**
  String get amneziaErrorNewerClientTitle;

  /// No description provided for @amneziaErrorNewerClientDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway refused this app’s version. It will work again once the app is updated.'**
  String get amneziaErrorNewerClientDetail;

  /// No description provided for @amneziaErrorCaptchaPass.
  ///
  /// In en, this message translates to:
  /// **'Pass it in the app this subscription came from, then refresh here.'**
  String get amneziaErrorCaptchaPass;

  /// No description provided for @amneziaErrorCaptchaExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'The CAPTCHA expired'**
  String get amneziaErrorCaptchaExpiredTitle;

  /// No description provided for @amneziaErrorCaptchaRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'The CAPTCHA was rejected'**
  String get amneziaErrorCaptchaRejectedTitle;

  /// No description provided for @amneziaErrorCaptchaAskedTitle.
  ///
  /// In en, this message translates to:
  /// **'The gateway asked for a CAPTCHA'**
  String get amneziaErrorCaptchaAskedTitle;

  /// {pass} is amneziaErrorCaptchaPass
  ///
  /// In en, this message translates to:
  /// **'This app cannot show one. {pass}'**
  String amneziaErrorCaptchaAskedDetail(String pass);

  /// No description provided for @amneziaErrorNotActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription not active'**
  String get amneziaErrorNotActiveTitle;

  /// No description provided for @amneziaErrorNotActiveDetail.
  ///
  /// In en, this message translates to:
  /// **'The gateway has no active subscription for this key.'**
  String get amneziaErrorNotActiveDetail;

  /// No description provided for @amneziaErrorLostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'This subscription lost its key'**
  String get amneziaErrorLostKeyTitle;

  /// No description provided for @amneziaErrorLostKeyDetail.
  ///
  /// In en, this message translates to:
  /// **'Remove the configuration and add it again.'**
  String get amneziaErrorLostKeyDetail;

  /// No description provided for @amneziaErrorFreeTierUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This subscription is free-tier, and its gateway asks for a CAPTCHA before it issues a configuration — which this app cannot show. Use the app it came from, or add a paid key here.'**
  String get amneziaErrorFreeTierUnsupported;

  /// No description provided for @importNotAKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'This isn’t a subscription key'**
  String get importNotAKeyTitle;

  /// No description provided for @importNotAKeyDetail.
  ///
  /// In en, this message translates to:
  /// **'Expected a vpn:// key from your subscription.'**
  String get importNotAKeyDetail;

  /// No description provided for @importKeyUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t supported here'**
  String importKeyUnsupportedTitle(String name);

  /// Name of a configuration made from pasted text with {count} servers
  ///
  /// In en, this message translates to:
  /// **'Imported ({count})'**
  String importImportedName(int count);

  /// No description provided for @importFormatLinks.
  ///
  /// In en, this message translates to:
  /// **'a link list'**
  String get importFormatLinks;

  /// No description provided for @importFormatClash.
  ///
  /// In en, this message translates to:
  /// **'a Clash / mihomo subscription'**
  String get importFormatClash;

  /// No description provided for @importFormatXray.
  ///
  /// In en, this message translates to:
  /// **'an Xray JSON subscription'**
  String get importFormatXray;

  /// No description provided for @importFormatSingbox.
  ///
  /// In en, this message translates to:
  /// **'a sing-box subscription'**
  String get importFormatSingbox;

  /// No description provided for @importFormatUnknown.
  ///
  /// In en, this message translates to:
  /// **'something unrecognised'**
  String get importFormatUnknown;

  /// No description provided for @importDetectedAmneziaKey.
  ///
  /// In en, this message translates to:
  /// **'{name} · subscription key'**
  String importDetectedAmneziaKey(String name);

  /// {type} is the protocol in capitals, e.g. VLESS
  ///
  /// In en, this message translates to:
  /// **'{type} server · {label}'**
  String importDetectedServer(String type, String label);

  /// No description provided for @importDetectedSubscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL · {host}'**
  String importDetectedSubscriptionUrl(String host);

  /// No description provided for @importDetectedSingleServer.
  ///
  /// In en, this message translates to:
  /// **'Server · {label}'**
  String importDetectedSingleServer(String label);

  /// No description provided for @importDetectedSubscriptionText.
  ///
  /// In en, this message translates to:
  /// **'Subscription · {count, plural, =1{1 server} other{{count} servers}}'**
  String importDetectedSubscriptionText(int count);

  /// No description provided for @importUnusableNotSubscriptionKey.
  ///
  /// In en, this message translates to:
  /// **'Not a subscription key'**
  String get importUnusableNotSubscriptionKey;

  /// {what} is a protocol or plugin name, e.g. 'ss+kcptun' or 'tuic://'
  ///
  /// In en, this message translates to:
  /// **'{what} isn’t supported'**
  String importUnusableNotSupported(String what);

  /// e.g. 'vless over kcp isn’t supported'
  ///
  /// In en, this message translates to:
  /// **'{scheme} over {transport} isn’t supported'**
  String importUnusableTransportNotSupported(String scheme, String transport);

  /// No description provided for @importUnusableLinkUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{scheme}:// link can’t be read'**
  String importUnusableLinkUnreadable(String scheme);

  /// No description provided for @importUnusableNotALink.
  ///
  /// In en, this message translates to:
  /// **'Not a link or subscription'**
  String get importUnusableNotALink;

  /// Section header in the service catalog
  ///
  /// In en, this message translates to:
  /// **'STREAMING'**
  String get catalogGroupStreaming;

  /// Section header in the service catalog
  ///
  /// In en, this message translates to:
  /// **'MESSENGERS'**
  String get catalogGroupMessengers;

  /// Section header in the service catalog
  ///
  /// In en, this message translates to:
  /// **'SOCIAL'**
  String get catalogGroupSocial;

  /// Section header in the service catalog
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get catalogGroupOther;

  /// What a proxy group of {count} servers does
  ///
  /// In en, this message translates to:
  /// **'Lowest latency of {count}'**
  String proxyGroupUrlTest(int count);

  /// No description provided for @proxyGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'First of {count} that answers · in their order'**
  String proxyGroupFallback(int count);

  /// No description provided for @proxyGroupLoadBalance.
  ///
  /// In en, this message translates to:
  /// **'Spread across {count}'**
  String proxyGroupLoadBalance(int count);

  /// No description provided for @proxyGroupRelay.
  ///
  /// In en, this message translates to:
  /// **'Chain of {count}'**
  String proxyGroupRelay(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
