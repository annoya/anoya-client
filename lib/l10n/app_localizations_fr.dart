// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonSettings => 'Réglages';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonDismiss => 'Ignorer';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get commonConnect => 'Se connecter';

  @override
  String get commonDisconnect => 'Se déconnecter';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonName => 'Nom';

  @override
  String get commonAll => 'Tous';

  @override
  String get commonFavorites => 'Favoris';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsCloudSync => 'Synchronisation iCloud';

  @override
  String get settingsCloudSyncing => 'Synchronisation…';

  @override
  String settingsCloudSynced(String ago) {
    return 'Synchronisé $ago';
  }

  @override
  String settingsCloudSyncFailed(String ago) {
    return 'Échec · dernière synchro $ago';
  }

  @override
  String get settingsCloudSyncFailedNever => 'Échec de la synchronisation';

  @override
  String get settingsCloudSyncUnavailable =>
      'Connectez-vous d’abord à iCloud sur cet appareil';

  @override
  String get settingsCloudSyncWaitingForKey =>
      'En attente de la clé du trousseau iCloud';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonJustNow => 'à l’instant';

  @override
  String get settingsSectionConfigurations => 'Configurations';

  @override
  String get settingsSectionConnection => 'Connexion';

  @override
  String get settingsSectionRouting => 'Routage';

  @override
  String get settingsSectionGeneral => 'Général';

  @override
  String get settingsSectionDiagnostics => 'Diagnostic';

  @override
  String get settingsSectionAbout => 'À propos';

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
  String get settingsAutoConnect => 'Connexion automatique';

  @override
  String get settingsAutoConnectSubtitle =>
      'Se connecter au démarrage de l’ordinateur';

  @override
  String get onDemandTitle => 'À la demande';

  @override
  String get settingsDisconnectOnSleep => 'Déconnecter en veille';

  @override
  String get settingsDisconnectOnSleepSubtitle =>
      'Couper le tunnel quand l’appareil se met en veille';

  @override
  String get settingsAlwaysOnSubtitle =>
      'Un réglage système — à définir dans les paramètres Android';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get settingsConnectionCheckOn =>
      'Vérification de la connexion · activée';

  @override
  String get settingsConnectionCheckOff =>
      'Vérification de la connexion · désactivée';

  @override
  String get settingsLanDirect => 'Réseau local en direct';

  @override
  String get settingsLanDirectSubtitle =>
      'Le trafic du réseau local contourne le VPN';

  @override
  String get ruleSetsTitle => 'Jeux de règles';

  @override
  String settingsRuleSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jeux',
      one: '1 jeu',
    );
    return '$_temp0';
  }

  @override
  String get settingsDefaultDns => 'DNS par défaut';

  @override
  String settingsDefaultDnsSubtitle(String name) {
    return '$name · utilisé quand la configuration n’en fournit aucun';
  }

  @override
  String get settingsDnsCustom => 'Personnalisé…';

  @override
  String get settingsDnsCustomSubtitle =>
      'toute adresse acceptée par le moteur';

  @override
  String get settingsDnsResolverLabel => 'Résolveur';

  @override
  String get settingsDnsUseCloudflare => 'Utiliser Cloudflare';

  @override
  String settingsGeoDownloaded(String size) {
    return 'téléchargé · $size';
  }

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsThemeSystemSubtitle => 'Suivre le réglage de l’appareil';

  @override
  String get aboutTitle => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutEngine => 'Moteur';

  @override
  String get aboutVersionCopied => 'Version copiée';

  @override
  String get aboutTermsOfService => 'Conditions d’utilisation';

  @override
  String get aboutPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get aboutNotPublishedYet => 'Pas encore publié';

  @override
  String get uiCouldNotOpenPage => 'Impossible d’ouvrir cette page.';

  @override
  String get advancedSectionConnectionCheck => 'Vérification de la connexion';

  @override
  String get advancedSectionLastCheck => 'Dernière vérification';

  @override
  String get advancedCheckAfterConnecting => 'Vérifier après la connexion';

  @override
  String get advancedCheckAfterConnectingSubtitle =>
      'Charger une page via le serveur et mesurer le temps de réponse';

  @override
  String get advancedTestUrl => 'URL de test';

  @override
  String get advancedUrlLabel => 'URL';

  @override
  String get advancedUseDefault => 'Utiliser la valeur par défaut';

  @override
  String get advancedInvalidUrl => 'Saisissez une adresse http:// ou https://.';

  @override
  String get advancedGiveUpAfter => 'Abandonner après';

  @override
  String advancedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '1 seconde',
    );
    return '$_temp0';
  }

  @override
  String get advancedTestNow => 'Tester maintenant';

  @override
  String get advancedNeedsTunnelNote =>
      'La requête passe par le moteur en cours d’exécution : le tunnel doit donc être actif pour la tester.';

  @override
  String get advancedCheckScopeNote =>
      'La requête passe par le serveur lui-même, les règles de routage ne s’y appliquent donc pas. Elle prouve que le serveur fait passer le trafic — pas que votre trafic passe par lui.';

  @override
  String get advancedNoAnswer => 'Pas de réponse';

  @override
  String advancedNoAnswerDetail(String failure) {
    return '$failure Le tunnel est actif : le problème vient donc du serveur ou du réseau au-delà.';
  }

  @override
  String get advancedTrafficGettingThrough => 'Le trafic passe';

  @override
  String advancedAnsweredIn(int ms) {
    return 'Réponse en $ms ms';
  }

  @override
  String advancedResultVia(String ago, String via) {
    return '$ago · via $via';
  }

  @override
  String commonMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String advancedHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String get alwaysOnTitle => 'VPN permanent';

  @override
  String get alwaysOnStartedBySystem => 'Démarré par le système';

  @override
  String get alwaysOnStartedBySystemSubtitle =>
      'Au démarrage, puis à chaque fois que le tunnel tombe';

  @override
  String get alwaysOnBlockWithoutVpn => 'Bloquer les connexions sans VPN';

  @override
  String get alwaysOnBlockWithoutVpnSubtitle =>
      'Le coupe-circuit du système, sur le même écran';

  @override
  String get alwaysOnNote =>
      'Ce réglage appartient à Android et se trouve donc dans les paramètres système : Réseau et Internet → VPN → l’engrenage à côté de cette app. Le système démarre la dernière configuration utilisée.';

  @override
  String get alwaysOnOpenSystemSettings => 'Ouvrir les réglages VPN du système';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get dnsSectionInEffect => 'En vigueur';

  @override
  String get dnsSectionDropped => 'Écartés';

  @override
  String get dnsParallelNote =>
      'Interrogés en même temps ; la première réponse l’emporte.';

  @override
  String get dnsFallbackNote =>
      'Cette configuration ne nomme aucun résolveur : l’app utilise donc celui par défaut — modifiable dans Réglages › DNS par défaut.';

  @override
  String get dnsProviderNote =>
      'Choisi par la personne qui a créé cette configuration, et mis à jour avec elle.';

  @override
  String get dnsProxyResolvedDirectlyNote =>
      'L’adresse du serveur par lequel vous vous connectez est toujours résolue en direct. C’est obligatoire — sinon rien ne pourrait atteindre le tunnel.';

  @override
  String dnsResolverSubtitle(String protocol, String origin) {
    return '$protocol · $origin';
  }

  @override
  String get dnsPinIgnoredTooltip =>
      'Cette configuration demandait une sortie que cette app ne crée pas ; la demande a été écartée et le résolveur est joint en direct.';

  @override
  String get dnsOriginAppDefault => 'défaut de l’app';

  @override
  String get dnsOriginSubscription => 'de votre abonnement';

  @override
  String get dnsOriginOrganisation => 'de votre organisation';

  @override
  String get dnsOriginConfiguration => 'de cette configuration';

  @override
  String get dnsRoutingDirect => 'en direct';

  @override
  String get dnsRoutingFollowsRules => 'selon vos règles';

  @override
  String get dnsRoutingThroughTunnel => 'via le tunnel';

  @override
  String get dnsProtocolDoh => 'DNS via HTTPS';

  @override
  String get dnsProtocolDot => 'DNS via TLS';

  @override
  String get dnsProtocolDoq => 'DNS via QUIC';

  @override
  String get dnsProtocolPlain => 'En clair, non chiffré';

  @override
  String get dnsDropMalformed =>
      'Ce n’est pas une adresse de résolveur. Rien de ce qui vient d’un abonnement n’entre dans la configuration du moteur sans vérification.';

  @override
  String get dnsDropUnknownScheme =>
      'Le moteur ne connaît pas ce schéma. Le garder aurait fait échouer toute la configuration, pas seulement cette ligne.';

  @override
  String get dnsDropCannotCarry =>
      'Le DNS en clair ne peut pas transiter par ce serveur, et l’envoyer hors du tunnel révélerait à votre réseau chaque site que vous visitez.';

  @override
  String dnsDropTooMany(int max) {
    return 'Au-delà des $max transmis au moteur. Il les interroge tous à la fois : une liste plus longue coûte du temps sans mieux répondre.';
  }

  @override
  String get dnsPresetQuad9Note => 'filtre les domaines malveillants connus';

  @override
  String get dnsPresetAdGuardNote => 'filtre les publicités et les traqueurs';

  @override
  String get dnsErrorNotResolverAddress =>
      'Ce n’est pas une adresse de résolveur.';

  @override
  String get dnsErrorAddressedByName =>
      'Désigné par un nom, il devrait donc être résolu avant de pouvoir résoudre quoi que ce soit. Utilisez son adresse IP.';

  @override
  String get geoTitle => 'GeoIP et GeoSite';

  @override
  String get geoSectionDatabases => 'Bases de données';

  @override
  String get geoSectionUpdates => 'Mises à jour';

  @override
  String get geoGeoipSource => 'Source GeoIP';

  @override
  String get geoGeositeSource => 'Source GeoSite';

  @override
  String get geoDownloadUrlLabel => 'URL de téléchargement';

  @override
  String get geoResetToDefault => 'Rétablir la valeur par défaut';

  @override
  String get geoNotDownloaded => 'non téléchargé';

  @override
  String get geoNever => 'jamais';

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String get geoLastUpdated => 'Dernière mise à jour';

  @override
  String get geoAutoUpdate => 'Mise à jour automatique';

  @override
  String get geoAutoUpdateSubtitle => 'Chaque semaine, une fois téléchargées';

  @override
  String get geoUpdateNow => 'Mettre à jour maintenant';

  @override
  String get geoUpdating => 'Mise à jour…';

  @override
  String get geoDownloading => 'Téléchargement…';

  @override
  String get geoDownload => 'Télécharger (~25 Mo)';

  @override
  String get geoDatabaseHostSubject => 'l’hébergeur des bases de données';

  @override
  String get geositeCategoryLabel => 'Catégorie';

  @override
  String geositeDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count domaines',
      one: '1 domaine',
    );
    return '$_temp0';
  }

  @override
  String get geositeNoCategories =>
      'Aucune catégorie — téléchargez d’abord les bases géo.';

  @override
  String uiNothingMatches(String query) {
    return 'Aucun résultat pour « $query ».';
  }

  @override
  String get geositeSectionPopular => 'Populaires';

  @override
  String geositeSectionAll(int count) {
    return 'Toutes · $count';
  }

  @override
  String geositeSectionAllMatch(int count, int total) {
    return 'Toutes · $count sur $total correspondent';
  }

  @override
  String get logsTitle => 'Journaux';

  @override
  String get logsSectionCollection => 'Collecte';

  @override
  String get logsSectionTunnel => 'Tunnel';

  @override
  String get logsSectionApp => 'App';

  @override
  String get logsCollect => 'Collecter les journaux';

  @override
  String get logsCollectSubtitle =>
      'Désactivé : l’app, le tunnel et le cœur cessent d’écrire. Les fichiers existants restent lisibles.';

  @override
  String get logsTunnel => 'Tunnel';

  @override
  String get logsTunnelSubtitle => 'Événements de la Network Extension';

  @override
  String get logsCore => 'Cœur (mihomo)';

  @override
  String get logsCoreSubtitle => 'Journal du moteur : connexions, DNS, routage';

  @override
  String get logsApplication => 'Application';

  @override
  String get logsApplicationSubtitle => 'Événements côté client';

  @override
  String get logsSaveAllZip => 'Enregistrer tous les journaux (.zip)';

  @override
  String get logsSaveAll => 'Enregistrer tous les journaux';

  @override
  String get logsSaveToFile => 'Enregistrer dans un fichier…';

  @override
  String get logsSaveToFileSubtitle => 'Choisir un dossier sur cet appareil';

  @override
  String get logsShare => 'Partager…';

  @override
  String get logsShareSubtitle => 'Envoyer l’archive ailleurs';

  @override
  String get logsSaveDialogTitle => 'Enregistrer les journaux';

  @override
  String logsSavedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get logsClearAll => 'Effacer tous les journaux';

  @override
  String get logsClearAllQuestion => 'Effacer tous les journaux ?';

  @override
  String get logsClearAllContent =>
      'Les journaux de l’app, du tunnel et du cœur seront supprimés de cet appareil.';

  @override
  String get logsCleared => 'Journaux effacés.';

  @override
  String get logsAppLogClearedOnly =>
      'Journal de l’app effacé. Ceux du tunnel et du cœur nécessitent que le VPN soit connecté.';

  @override
  String get logsNoLog => 'Aucun journal.';

  @override
  String get logsNoLogYet => 'Aucun journal pour l’instant.';

  @override
  String get logsEmpty => 'Vide';

  @override
  String get logsUnavailable =>
      'Les journaux ne sont disponibles que lorsque le tunnel est actif.\n(Le processus du tunnel conserve ses journaux de son côté et les transmet à l’app par IPC.)';

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String configKindSelfhosted(String servers) {
    return 'Auto-hébergé · $servers';
  }

  @override
  String configKindSubscription(String servers, String groups) {
    return 'Abonnement · $servers$groups';
  }

  @override
  String get configKindSubscriptionPlain => 'Abonnement';

  @override
  String get configKindSingleServer => 'Serveur unique';

  @override
  String commonServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '1 serveur',
    );
    return '$_temp0';
  }

  @override
  String configServersOfOffered(int ours, int offered) {
    String _temp0 = intl.Intl.pluralLogic(
      offered,
      locale: localeName,
      other: '$ours sur $offered serveurs',
      one: '$ours serveur sur 1',
    );
    return '$_temp0';
  }

  @override
  String configGroupsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count groupes',
      one: ' · 1 groupe',
    );
    return '$_temp0';
  }

  @override
  String get configSource => 'Source';

  @override
  String get configSourceViaFallback =>
      'La dernière actualisation a utilisé l’adresse de secours de l’abonnement';

  @override
  String get configCouldNotOpenLink => 'Impossible d’ouvrir ce lien.';

  @override
  String get configLinkCopied => 'Lien copié';

  @override
  String configUnsupportedTitle(int skipped, int offered) {
    return '$skipped serveurs sur $offered non pris en charge';
  }

  @override
  String configUnsupportedDetail(String kinds, int available) {
    return 'Ils utilisent $kinds, que cette app ne sait pas encore exécuter. Les $available autres sont disponibles.';
  }

  @override
  String get configSetActive => 'Activer';

  @override
  String get configRemoveConfiguration => 'Retirer la configuration';

  @override
  String configRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get configRemoveDetail =>
      'Cette configuration sera retirée de cet appareil.';

  @override
  String get configSectionSubscription => 'Abonnement';

  @override
  String get configDevices => 'Appareils';

  @override
  String configDevicesUsed(int active, int max) {
    return '$active sur $max utilisés';
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
  String get accountExpiredTitle => 'Abonnement expiré';

  @override
  String get configSubscriptionExpiredDetail =>
      'Renouvelez l’abonnement, puis actualisez cette configuration.';

  @override
  String get configSectionThisDevice => 'Cet appareil';

  @override
  String get configDeviceIdentifiedSubtitle =>
      'Identifié auprès de votre abonnement, qui compte les appareils';

  @override
  String get configDeviceId => 'Identifiant de l’appareil';

  @override
  String get configDeviceHintAmnezia =>
      'Votre abonnement compte les appareils par cet identifiant. Il est créé une fois et conservé : se reconnecter ne coûte aucune place — mais une réinstallation en prend une nouvelle.';

  @override
  String get configDevicesFull => 'Plus de place libre';

  @override
  String get configDeviceHwid => 'HWID';

  @override
  String get configDeviceSentSubtitle =>
      'Envoyé à l’abonnement à chaque actualisation';

  @override
  String get configDeviceHintPanelUncounted =>
      'L’app envoie cet id à chaque actualisation, pour qu’un abonnement qui limite les appareils puisse les distinguer. Il est créé une fois et conservé ; une réinstallation en crée un nouveau.';

  @override
  String get configDeviceHintPanel =>
      'Votre abonnement compte les appareils grâce à un identifiant que cette app génère une fois et conserve. Une réinstallation en crée un nouveau, qui occupe une place de plus.';

  @override
  String configCopiedTitle(String title) {
    return '$title copié';
  }

  @override
  String configDnsSummary(String host, String routing) {
    return '$host · $routing';
  }

  @override
  String configDnsMore(int count) {
    return ' · +$count autres';
  }

  @override
  String configDnsDropped(int count) {
    return '$count écartés';
  }

  @override
  String get configDnsByApp => 'DNS de l’app';

  @override
  String configDnsOrigin(String origin) {
    return 'DNS $origin';
  }

  @override
  String configDnsRefused(int count) {
    return 'DNS : $count refusés';
  }

  @override
  String get configRouting => 'Routage';

  @override
  String get configRuleSet => 'Jeu de règles';

  @override
  String get configRuleSetDefault => 'Par défaut';

  @override
  String get configRuleLists => 'Listes de règles';

  @override
  String get ruleSetModeSplit => 'Sélectif';

  @override
  String get ruleSetModeFull => 'Tunnel complet';

  @override
  String ruleSetSummary(String mode, String rules) {
    return '$mode · $rules';
  }

  @override
  String get ruleSetNoRules => 'aucune règle';

  @override
  String get configNoExceptions => 'aucune exception';

  @override
  String configRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles',
      one: '1 règle',
    );
    return '$_temp0';
  }

  @override
  String configSkippedNotSupported(int count) {
    return '$count non prises en charge';
  }

  @override
  String configListsUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listes indisponibles',
      one: '1 liste indisponible',
    );
    return '$_temp0';
  }

  @override
  String configRulesNeedLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ont besoin de leurs listes',
      one: '1 a besoin de sa liste',
    );
    return '$_temp0';
  }

  @override
  String configDownloadingLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Téléchargement de $count listes…',
      one: 'Téléchargement d’une liste…',
    );
    return '$_temp0';
  }

  @override
  String configRuleListsOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles en ont besoin',
      one: '1 règle en a besoin',
    );
    return 'Désactivées · $_temp0';
  }

  @override
  String get configChecking => 'Vérification…';

  @override
  String get configNoneDownloadedYet => 'Aucune téléchargée pour l’instant';

  @override
  String configListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listes',
      one: '1 liste',
    );
    return '$_temp0';
  }

  @override
  String configListsDownloadedOf(int have, int total) {
    return '$have sur $total téléchargées';
  }

  @override
  String configListsSize(String count, int kb) {
    return '$count · $kb Ko';
  }

  @override
  String configListsFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listes n’ont pas pu être téléchargées',
      one: 'Une liste n’a pas pu être téléchargée',
    );
    return '$_temp0';
  }

  @override
  String configListsFailedDetail(int count, String names, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names depuis $hosts — les règles qui les utilisent ne sont pas appliquées.',
      one: '$names depuis $hosts — la règle qui l’utilise n’est pas appliquée.',
    );
    return '$_temp0';
  }

  @override
  String configReplacedBy(String name) {
    return 'Remplacé par $name';
  }

  @override
  String get configRoutingOffSummary => 'Désactivé · tout passe par le VPN';

  @override
  String get configManagedByOrganization => 'Géré par votre organisation';

  @override
  String configManagedSummary(String mode, int count) {
    return '$mode · $count règles, définies sur le serveur';
  }

  @override
  String configSetByOrganization(String mode) {
    return '$mode · défini par votre organisation';
  }

  @override
  String get configSectionOrganizationRouting => 'Routage de l’organisation';

  @override
  String get configSectionSubscriptionRouting => 'Routage de l’abonnement';

  @override
  String get configSectionDeviceRouting => 'Routage de l’appareil';

  @override
  String get configOrganizationRoutingNote =>
      'Votre organisation définit cette politique et l’applique. Vous pouvez la consulter ; toute modification se fait de son côté.';

  @override
  String get configSubscriptionRoutes => 'les routes de l’abonnement';

  @override
  String get configSubscriptionRoutingNote =>
      'Désactivez l’interrupteur pour utiliser votre propre jeu de règles. Votre abonnement ne peut l’imposer ni dans un sens ni dans l’autre.';

  @override
  String get configDeviceRoutingNote =>
      'Les jeux de règles sont partagés par toutes les configurations ; l’interrupteur est propre à chacune, si bien qu’un abonnement professionnel et un abonnement personnel peuvent utiliser le même jeu différemment.';

  @override
  String get configGetSupport => 'Obtenir de l’aide';

  @override
  String get configNoPlanDetails =>
      'Votre abonnement n’a communiqué aucun détail de forfait.';

  @override
  String configUsedNoLimit(String used) {
    return 'Utilisé $used · sans limite';
  }

  @override
  String get configTraffic => 'Trafic';

  @override
  String configTrafficUsedOf(String used, String total) {
    return '$used sur $total';
  }

  @override
  String get configNoExpiryDate => 'Aucune date d’expiration indiquée';

  @override
  String configActiveUntil(String date) {
    return 'Actif jusqu’au $date';
  }

  @override
  String configTermLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Encore $days jours',
      one: 'Plus qu’un jour',
      zero: 'Se termine aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get configExpired => 'L’abonnement a expiré';

  @override
  String configEndedOn(String date) {
    return 'Terminé le $date';
  }

  @override
  String get configRenew => 'Renouveler l’abonnement';

  @override
  String get configAccount => 'Compte';

  @override
  String configStatus(String status) {
    return 'Statut : $status';
  }

  @override
  String configStatusOnHold(String status) {
    return 'Statut : $status · démarre à la première utilisation';
  }

  @override
  String get configLastRefreshed => 'Dernière actualisation';

  @override
  String get configRefreshEvery => 'Actualiser toutes les';

  @override
  String get configHours => 'Heures';

  @override
  String get configRefreshAsSubscriptionAsks => 'Selon l’abonnement';

  @override
  String get configRefreshEnterWholeHours =>
      'Saisissez un nombre entier d’heures.';

  @override
  String configRefreshNever(String every) {
    return 'jamais · $every';
  }

  @override
  String configRefreshAgo(String ago, String every) {
    return '$ago · $every';
  }

  @override
  String configAutoEveryMinutes(int count) {
    return 'auto toutes les $count min';
  }

  @override
  String configAutoEveryHours(int count) {
    return 'auto toutes les $count h';
  }

  @override
  String configAutoEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'auto tous les $count jours',
      one: 'auto chaque jour',
    );
    return '$_temp0';
  }

  @override
  String get configRefreshNow => 'Actualiser maintenant';

  @override
  String configRefreshFailed(String detail) {
    return 'Actualisation impossible — $detail';
  }

  @override
  String get configRefreshFailedFallback =>
      'affichage des serveurs déjà connus.';

  @override
  String get configOrganizationPolicyDetail =>
      'Ces règles sont définies sur le serveur et ne peuvent pas être modifiées ici.';

  @override
  String configSentBy(String name) {
    return 'Envoyé par $name';
  }

  @override
  String get configProviderPolicyDetail =>
      'Lecture seule. L’actualisation de l’abonnement les remplace.';

  @override
  String configProviderPolicyDetailSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count règles supplémentaires n’ont pas pu être traduites pour cette app et ne sont pas appliquées.',
      one:
          '1 règle supplémentaire n’a pas pu être traduite pour cette app et n’est pas appliquée.',
    );
    return 'Lecture seule. L’actualisation de l’abonnement les remplace. $_temp0';
  }

  @override
  String get ruleSetSplitTunneling => 'Tunnel sélectif';

  @override
  String get ruleSetGeoNotDownloaded => 'Bases géo non téléchargées';

  @override
  String get ruleSetGeoNotDownloadedDetail =>
      'les règles geoip / geosite restent inactives jusque-là (~25 Mo)';

  @override
  String get ruleSetRulesHeader =>
      'Règles — la première correspondance l’emporte';

  @override
  String get homeAddConfiguration => 'Ajouter une configuration';

  @override
  String get homeConfigurationSettings => 'Réglages de la configuration';

  @override
  String homeChipAuto(String state) {
    return 'Auto · $state';
  }

  @override
  String homeChipRouting(String state) {
    return 'Routage · $state';
  }

  @override
  String homeChipLogs(String state) {
    return 'Journaux · $state';
  }

  @override
  String get homeStateOn => 'activé';

  @override
  String get homeStateOff => 'désactivé';

  @override
  String get homeAutoPaused => 'en pause';

  @override
  String get homeAutoNotArmed => 'non armé';

  @override
  String get homeCheckFailedTitle => 'Connecté, mais aucune réponse';

  @override
  String get homeCheckFailedDetail =>
      'La vérification n’a obtenu aucune réponse via ce serveur. Essayez-en un autre, ou ouvrez Avancé.';

  @override
  String get homeAutoConnectPausedTitle => 'Connexion automatique en pause';

  @override
  String get homeAutoConnectPausedDetail =>
      'Appuyez sur Se connecter pour la réarmer';

  @override
  String get homeAutoConnectNotArmedTitle =>
      'Connexion automatique pas encore armée';

  @override
  String get homeAutoConnectNotArmedDetail =>
      'Connectez-vous une fois pour que le système prenne le relais';

  @override
  String get homeNoServers => 'Aucun serveur';

  @override
  String get homeGroupAuto => 'auto';

  @override
  String homeGroupAutoPicked(String server) {
    return 'auto · $server';
  }

  @override
  String get homeConfiguration => 'Configuration';

  @override
  String homeExpiryEndsIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'L’abonnement se termine dans $days jours',
      one: 'L’abonnement se termine dans 1 jour',
      zero: 'L’abonnement se termine aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String homeExpiryTraffic(int percent) {
    return '$percent % du trafic utilisé';
  }

  @override
  String homeExpiryValidUntil(String date) {
    return 'Valable jusqu’au $date';
  }

  @override
  String get homeServer => 'Serveur';

  @override
  String get homeChosenByEngine => 'Choisi par le moteur';

  @override
  String get homeSwitchingServer => 'Changement de serveur…';

  @override
  String get homeGettingServer => 'Récupération du serveur…';

  @override
  String get statusConnected => 'Connecté';

  @override
  String homeConnectedClock(String clock) {
    return 'Connecté · $clock';
  }

  @override
  String homeStatusAuto(String status) {
    return '$status · auto';
  }

  @override
  String get statusConnecting => 'Connexion…';

  @override
  String get statusError => 'Erreur';

  @override
  String get statusNotConnected => 'Non connecté';

  @override
  String homeGroupRechecks(String summary, int minutes) {
    return '$summary · revérifie toutes les $minutes min';
  }

  @override
  String get startCouldntReadFile => 'Impossible de lire le fichier';

  @override
  String get startCouldntReadFileDetail =>
      'Réessayez de l’ouvrir, ou collez son contenu.';

  @override
  String get startAddConnection => 'Ajouter une connexion';

  @override
  String get startSubtitle => 'Lien, abonnement ou fichier de configuration';

  @override
  String get startLinkLabel => 'Lien ou abonnement';

  @override
  String get startLinkHint => 'vless://…  ou  https://…/sub';

  @override
  String get startPaste => 'Coller';

  @override
  String get startClipboardEmpty => 'Le presse-papiers est vide';

  @override
  String get secretsInFileNotice =>
      'Aucun trousseau sur ce système — les données de connexion sont conservées dans un fichier lisible uniquement par votre compte.';

  @override
  String get ruleSetImport => 'Importer un jeu de règles';

  @override
  String get ruleSetImportFromFile => 'Depuis un fichier…';

  @override
  String get ruleSetImportFromFileSubtitle =>
      'Anoya, Clash / mihomo, Shadowrocket, Surge, Happ';

  @override
  String get ruleSetImportFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get ruleSetImportFromClipboardSubtitle =>
      'Un jeu de règles ou un lien happ://routing';

  @override
  String get ruleSetImportScanSubtitle => 'Depuis un autre appareil';

  @override
  String get ruleSetImportScanHint =>
      'Un jeu de règles d’Anoya ou un profil de routage Happ';

  @override
  String get ruleSetImportNotARuleSet => 'ce n’est pas un jeu de règles';

  @override
  String get ruleSetImportUnreadable =>
      'Impossible de lire un jeu de règles. Anoya lit ses propres fichiers, les règles Clash / mihomo et Shadowrocket / Surge, et les profils de routage Happ.';

  @override
  String get ruleSetImportTitle => 'Importer un jeu de règles';

  @override
  String get ruleSetImportSourceAnoya => 'Jeu de règles Anoya';

  @override
  String get ruleSetImportSourceClash => 'Règles Clash / mihomo';

  @override
  String get ruleSetImportSourceSurge => 'Règles Shadowrocket / Surge';

  @override
  String get ruleSetImportSourceHapp => 'Profil de routage Happ';

  @override
  String get ruleSetImportAsIs => 'Rien à convertir';

  @override
  String get ruleSetImportMigrated => 'Migré vers un jeu de règles Anoya';

  @override
  String ruleSetImportRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles',
      one: '1 règle',
      zero: 'Aucune règle',
    );
    return '$_temp0';
  }

  @override
  String ruleSetImportDirect(int count) {
    return '$count en direct';
  }

  @override
  String ruleSetImportProxy(int count) {
    return '$count via le VPN';
  }

  @override
  String ruleSetImportBlock(int count) {
    return '$count bloquées';
  }

  @override
  String get ruleSetImportSkipped => 'Non repris';

  @override
  String get ruleSetImportSkipDns => 'Serveurs DNS';

  @override
  String get ruleSetImportSkipDnsDetail =>
      'Définis par configuration dans Anoya';

  @override
  String get ruleSetImportSkipGeo => 'Liens des bases géo';

  @override
  String get ruleSetImportSkipGeoDetail =>
      'Anoya utilise les siennes, dans les Réglages';

  @override
  String ruleSetImportSkipLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles avec des listes par lien',
      one: '1 règle avec une liste par lien',
    );
    return '$_temp0';
  }

  @override
  String get ruleSetImportSkipListsDetail =>
      'Les listes par lien ne font pas partie de vos propres jeux';

  @override
  String ruleSetImportSkipOther(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles qu’Anoya ne peut pas exécuter',
      one: '1 règle qu’Anoya ne peut pas exécuter',
    );
    return '$_temp0';
  }

  @override
  String get ruleSetImportAdd => 'Ajouter le jeu';

  @override
  String ruleSetImportAdded(String name) {
    return 'Jeu « $name » ajouté';
  }

  @override
  String get ruleSetImportDefaultName => 'Jeu importé';

  @override
  String get ruleSetExport => 'Exporter';

  @override
  String ruleSetExportTitle(String name) {
    return 'Exporter « $name »';
  }

  @override
  String get ruleSetExportShare => 'Partager…';

  @override
  String get ruleSetExportShareSubtitle =>
      'Envoyer le fichier vers une autre app ou un autre appareil';

  @override
  String get ruleSetExportSave => 'Enregistrer dans un fichier…';

  @override
  String get ruleSetExportCopy => 'Copier dans le presse-papiers';

  @override
  String get ruleSetExportCopySubtitle => 'Sous forme de lien anoya://ruleset';

  @override
  String get ruleSetExportQr => 'Afficher un code QR';

  @override
  String get ruleSetExportQrSubtitle =>
      'Scannez-le dans Anoya sur un autre appareil';

  @override
  String get ruleSetExportQrTooLarge =>
      'Trop grand pour un code QR — partagez-le en fichier';

  @override
  String get ruleSetQrHint =>
      'Dans Anoya sur l’autre appareil : Jeux de règles → Importer → Scanner un code QR.';

  @override
  String get startScanQr => 'Scanner un code QR';

  @override
  String get qrHint => 'Pointez la caméra vers un code QR';

  @override
  String get qrHintDetail => 'Un lien, un abonnement ou une clé d’abonnement';

  @override
  String qrParts(int received, int total) {
    return 'Clé d’abonnement · partie $received sur $total — gardez la caméra sur le code';
  }

  @override
  String get qrPartsDetail =>
      'L’application affiche les parties l’une après l’autre';

  @override
  String get qrStillLooking => 'Recherche en cours — visez un autre code';

  @override
  String get qrFromPhotos => 'Choisir dans les photos';

  @override
  String get qrNoCamera => 'Pas d’accès à la caméra';

  @override
  String get qrNoCameraDetail =>
      'Autorisez l’accès à la caméra dans les réglages du système ou choisissez une capture d’écran du code QR.';

  @override
  String get qrNoCodeInImage => 'Aucun code QR trouvé dans cette image';

  @override
  String get qrTorch => 'Lampe torche';

  @override
  String startCantUseThis(String reason) {
    return 'Inutilisable · $reason';
  }

  @override
  String get startOpenConfigFile => 'Ouvrir un fichier de configuration…';

  @override
  String get startOr => 'ou';

  @override
  String get startSignInToServer => 'S’identifier sur votre serveur';

  @override
  String get startOpenSubscriptionPage => 'Ouvrir la page de l’abonnement';

  @override
  String get signInEnterServerFirst => 'Saisissez d’abord l’adresse du serveur';

  @override
  String get signInNoSsoProviders => 'Ce serveur n’a aucun fournisseur SSO';

  @override
  String get signInNoSsoProvidersDetail =>
      'Identifiez-vous plutôt avec un nom d’utilisateur et un mot de passe.';

  @override
  String get signInWith => 'S’identifier avec';

  @override
  String get signIn => 'S’identifier';

  @override
  String get signInSubtitle => 'Le serveur de votre organisation ou le vôtre';

  @override
  String get signInServerAddress => 'Adresse du serveur';

  @override
  String get signInServerHint => 'https://votre-serveur';

  @override
  String get signInUsername => 'Nom d’utilisateur';

  @override
  String get signInPassword => 'Mot de passe';

  @override
  String get signInWithSso => 'S’identifier via SSO';

  @override
  String get uiNounItem => 'élément';

  @override
  String get uiNounServer => 'serveur';

  @override
  String get uiNounCountry => 'pays';

  @override
  String get uiRemoveFromFavorites => 'Retirer des favoris';

  @override
  String get uiAddToFavorites => 'Ajouter aux favoris';

  @override
  String get uiAllNothingMatches => 'Tous · aucun résultat';

  @override
  String uiAllMatchCount(int shown, int total) {
    return 'Tous · $shown sur $total correspondent';
  }

  @override
  String uiNoMatches(String noun, String query, int total) {
    return 'Pas de $noun correspondant à « $query ». Effacez la recherche pour tout afficher ($total).';
  }

  @override
  String get ruleSetModeFullDescription =>
      'Tout le trafic passe par le VPN ; les règles définissent les exceptions.';

  @override
  String get ruleSetModeSplitDescription =>
      'Seul le trafic correspondant aux règles passe par le VPN ; le reste se connecte en direct.';

  @override
  String get ruleSetNoRulesSplit =>
      'Aucune règle : aucun trafic ne passe par le VPN. Ajoutez des règles pour ce qui doit passer par le tunnel.';

  @override
  String get ruleSetNoRulesFull =>
      'Aucune règle : tout le trafic passe par le VPN.';

  @override
  String get ruleSetDownload => 'Télécharger';

  @override
  String get ruleKindRuleList => 'liste de règles';

  @override
  String ruleInactiveNoDatabase(String kind) {
    return '$kind · inactive — pas de base de données';
  }

  @override
  String ruleInactiveDesktopOnly(String kind) {
    return '$kind · inactive — ordinateur uniquement';
  }

  @override
  String ruleInactiveListsOff(String kind) {
    return '$kind · inactive — listes désactivées';
  }

  @override
  String ruleInactiveNotDownloaded(String kind) {
    return '$kind · inactive — non téléchargée';
  }

  @override
  String ruleNoResolveKind(String kind) {
    return '$kind · no-resolve';
  }

  @override
  String get ruleTypeDomainSuffix => 'domaine et sous-domaines';

  @override
  String get ruleTypeDomainKeyword => 'le domaine contient';

  @override
  String get ruleTypeDomainExact => 'domaine exact';

  @override
  String get ruleTypeIpCidr => 'plage d’IP';

  @override
  String get ruleTypeProcessName => 'app par son nom';

  @override
  String get ruleTypeGeoip => 'pays par IP';

  @override
  String get ruleTypeGeosite => 'listes de domaines';

  @override
  String get ruleTypeDomainRegex => 'domaine selon un motif';

  @override
  String get ruleTypeRuleList => 'une liste de votre abonnement';

  @override
  String get rulePickCountry => 'Choisissez un pays.';

  @override
  String ruleInvalidValue(String type) {
    return 'Valeur invalide pour $type.';
  }

  @override
  String get ruleMatch => 'Critère';

  @override
  String get ruleNotAvailableOnPlatform => 'indisponible sur cette plateforme';

  @override
  String get ruleNeedsGeoDatabases => 'nécessite les bases géo';

  @override
  String get ruleAction => 'Action';

  @override
  String get ruleActionProxyDescription => 'via le VPN';

  @override
  String get ruleActionDirectDescription => 'contourner le VPN';

  @override
  String get ruleActionBlockDescription => 'couper la connexion';

  @override
  String get ruleAdd => 'Ajouter une règle';

  @override
  String get ruleEdit => 'Modifier la règle';

  @override
  String get ruleCountry => 'Pays';

  @override
  String get ruleChoose => 'Choisir…';

  @override
  String get ruleNoResolveDescription =>
      'Ne traiter que les connexions vers des IP, sans résoudre les domaines';

  @override
  String get ruleValue => 'Valeur';

  @override
  String ruleSummaryGeoip(String country) {
    return 'le trafic vers les IP du pays « $country »';
  }

  @override
  String ruleSummaryGeosite(String category) {
    return 'le trafic vers les domaines « $category » (liste GeoSite)';
  }

  @override
  String ruleSummaryProcess(String name) {
    return 'le trafic de « $name »';
  }

  @override
  String ruleSummaryMatching(String value) {
    return 'le trafic correspondant à $value';
  }

  @override
  String get ruleSummaryProxy => 'passe par le VPN';

  @override
  String get ruleSummaryDirect =>
      'se connecte en direct, sans passer par le VPN';

  @override
  String get ruleSummaryBlock => 'est bloqué';

  @override
  String ruleSummary(String target, String verb) {
    return '→ $target $verb.';
  }

  @override
  String ruleSetDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get ruleSetDeleteBody =>
      'Les configurations qui utilisent ce jeu reviendront à Par défaut.';

  @override
  String get ruleSetDeleteTooltip => 'Supprimer le jeu de règles';

  @override
  String get ruleSetSimple => 'Simple';

  @override
  String get ruleSetDownloadSiteLists =>
      'Téléchargez d’abord les listes de sites';

  @override
  String get ruleSetDownloadSiteListsDetail =>
      'Choisir des services nécessite les bases géo (~25 Mo, une seule fois)';

  @override
  String ruleSetAdvancedRules(int count) {
    return 'Règles avancées · $count';
  }

  @override
  String get ruleSetAdvancedRulesDetail =>
      'Appliquées avant la liste ci-dessous · à modifier dans Avancé';

  @override
  String get ruleSetSearchServices => 'Rechercher des services';

  @override
  String get ruleSetCountriesHeader => 'Pays';

  @override
  String get ruleSetAddCountry => 'Ajouter un pays';

  @override
  String get ruleSetServicesHeader => 'Services';

  @override
  String get ruleSetAddCategory => 'Ajouter une catégorie';

  @override
  String get ruleSetOtherCategoriesHeader => 'Autres catégories';

  @override
  String get ruleSetNothingSelectedSplit =>
      'Rien de sélectionné · aucun trafic ne passe encore par le VPN';

  @override
  String get ruleSetNothingSelectedFull =>
      'Rien de sélectionné · tout passe par le VPN';

  @override
  String ruleSetSelectedSplit(int count) {
    return '$count sélectionnés · tout le reste se connecte en direct';
  }

  @override
  String ruleSetSelectedFull(int count) {
    return '$count sélectionnés · ils se connectent en direct, le reste passe par le VPN';
  }

  @override
  String get ruleSetOnlySelected => 'Seulement la sélection';

  @override
  String get ruleSetAllExceptSelected => 'Tout sauf la sélection';

  @override
  String get ruleSetOnlySelectedDescription =>
      'Seuls les services choisis passent par le VPN. Tout le reste se connecte en direct.';

  @override
  String get ruleSetAllExceptSelectedDescription =>
      'Tout passe par le VPN. Les services choisis se connectent en direct.';

  @override
  String get ruleSetNew => 'Nouveau jeu de règles';

  @override
  String get ruleSetNameHint => 'Travail';

  @override
  String ruleSetNameTaken(String name) {
    return 'Un ensemble nommé « $name » existe déjà';
  }

  @override
  String get ruleSetCreate => 'Créer';

  @override
  String ruleSetRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles',
      one: '1 règle',
      zero: 'aucune règle',
    );
    return '$_temp0';
  }

  @override
  String ruleSetUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'utilisé par $count configurations',
      one: 'utilisé par 1 configuration',
    );
    return '$_temp0';
  }

  @override
  String ruleSetSummaryUsed(String mode, String rules, String used) {
    return '$mode · $rules · $used';
  }

  @override
  String get onDemandEnable => 'Activer à la demande';

  @override
  String get onDemandEnableSubtitle =>
      'Le système applique la première règle qui correspond';

  @override
  String get onDemandNoRules =>
      'Aucune règle. Activer à la demande ajoute « Se connecter · Tout réseau ».';

  @override
  String get onDemandRulesFootnote =>
      'Les règles sont évaluées de haut en bas. Si aucune ne correspond, le tunnel reste tel quel.';

  @override
  String get onDemandTagConnect => 'CONNECTER';

  @override
  String get onDemandTagDisconnect => 'DÉCONNECTER';

  @override
  String get onDemandTagIgnore => 'IGNORER';

  @override
  String get onDemandNewRule => 'Nouvelle règle';

  @override
  String get onDemandActionIgnore => 'Ignorer';

  @override
  String get onDemandActionConnectSubtitle => 'monter le tunnel';

  @override
  String get onDemandActionDisconnectSubtitle => 'couper le tunnel';

  @override
  String get onDemandActionIgnoreSubtitle => 'laisser le tunnel tel quel';

  @override
  String get onDemandAny => 'Tous';

  @override
  String get onDemandNameOptional => 'Nom (facultatif)';

  @override
  String get onDemandNameHint => 'Bureau';

  @override
  String get onDemandNetworkHeader => 'Réseau';

  @override
  String get onDemandNetworkHelpAny =>
      'La règle est vérifiée sur tous les réseaux — Wi-Fi, mobile ou filaire.';

  @override
  String get onDemandNetworkHelpWifi =>
      'Quand l’appareil rejoint un réseau Wi-Fi, le système vérifie les conditions ci-dessous et applique la règle.';

  @override
  String get onDemandNetworkHelpCellular =>
      'Quand l’appareil est en données mobiles, le système vérifie les conditions ci-dessous et applique la règle.';

  @override
  String get onDemandNetworkHelpEthernet =>
      'Quand l’appareil est sur un réseau filaire, le système vérifie les conditions ci-dessous et applique la règle.';

  @override
  String get onDemandConditionsHeader => 'Conditions';

  @override
  String get onDemandWifiNetworks => 'Réseaux Wi-Fi';

  @override
  String get onDemandWifiNetwork => 'Réseau Wi-Fi';

  @override
  String get onDemandNetworksUnit => 'réseaux';

  @override
  String get onDemandWifiNetworksHelp =>
      'Correspond exactement au nom du réseau. Laissez vide pour tout Wi-Fi.';

  @override
  String get onDemandDnsDomains => 'Domaines de recherche DNS';

  @override
  String get onDemandDnsDomain => 'Domaine de recherche DNS';

  @override
  String get onDemandDomainsUnit => 'domaines';

  @override
  String get onDemandDnsDomainsHelp =>
      'Correspond quand le domaine de recherche du réseau se termine par une des entrées.';

  @override
  String get onDemandDnsServers => 'Serveurs DNS';

  @override
  String get onDemandDnsServer => 'Serveur DNS';

  @override
  String get onDemandServersUnit => 'serveurs';

  @override
  String get onDemandDnsServersHelp =>
      'Correspond aux serveurs DNS du réseau ; un seul joker « * » est autorisé.';

  @override
  String get onDemandUrlProbeHeader => 'Sonde URL';

  @override
  String get onDemandUrlOptional => 'URL (facultatif)';

  @override
  String get onDemandUrlProbeHelp =>
      'La règle ne correspond que si cette URL renvoie 200 sans redirection.';

  @override
  String get onDemandNoEntries => 'Aucune entrée';

  @override
  String onDemandEntriesHeader(int count, String unit) {
    return '$count $unit · une seule correspondance suffit';
  }

  @override
  String get onDemandConditionIgnored =>
      'La condition est ignorée et la règle correspond à tout réseau du type sélectionné.';

  @override
  String get onDemandInterfaceAny => 'Tout réseau';

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
    return 'domaine $values';
  }

  @override
  String onDemandSummaryDns(String values) {
    return 'DNS $values';
  }

  @override
  String get onDemandSummaryProbe => 'sonde';

  @override
  String get onDemandStatusPaused => 'En pause';

  @override
  String get onDemandStatusAwaitingFirstConnect =>
      'Activé · après la première connexion';

  @override
  String onDemandStatusOnRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activé · $count règles',
      one: 'Activé · 1 règle',
    );
    return '$_temp0';
  }

  @override
  String get onDemandDefaultRuleName => 'Partout';

  @override
  String get statusNoConfiguration => 'Aucune configuration';

  @override
  String get menuBarSwitching => 'Changement…';

  @override
  String profilesCouldntGetServer(String label) {
    return 'Impossible d’obtenir le serveur pour $label';
  }

  @override
  String get profilesPreviousServerStillInUse =>
      'Le précédent est toujours utilisé.';

  @override
  String get profilesCouldntSwitch => 'Changement impossible';

  @override
  String get profilesCouldntSwitchDetail =>
      'Le tunnel a gardé la configuration précédente. Réessayez, ou reconnectez-vous.';

  @override
  String get profilesNoConfigurationDetail =>
      'Ajoutez un lien, un abonnement, ou identifiez-vous sur votre serveur.';

  @override
  String get profilesNoServers => 'Cette configuration n’a aucun serveur';

  @override
  String get profilesNoServersDetail =>
      'Actualisez-la, ou ajoutez une autre configuration.';

  @override
  String get profilesTunnelStopped => 'Le tunnel s’est arrêté';

  @override
  String get connectionCheckTimedOut => 'Le serveur n’a pas répondu à temps.';

  @override
  String get connectionCheckClosed => 'Le serveur a fermé la connexion.';

  @override
  String get connectionCheckRefused => 'Le serveur a refusé la connexion.';

  @override
  String get connectionCheckNoServer =>
      'Aucun serveur à tester — le tunnel exécute autre chose.';

  @override
  String get connectionCheckTunnelNotRunning => 'Le tunnel n’est pas actif.';

  @override
  String get connectionCheckNothingCameBack => 'Aucune réponse.';

  @override
  String get connectionCheckEngineDidNotAnswer => 'Le moteur n’a pas répondu.';

  @override
  String get errorDeviceLimitTitle => 'Limite d’appareils atteinte';

  @override
  String get errorDeviceLimitDetail =>
      'La limite d’appareils de votre abonnement est atteinte : il a envoyé un substitut à la place de vos serveurs. Libérez une place dans votre abonnement, puis actualisez.';

  @override
  String get errorUnreadableSubscriptionTitle =>
      'Impossible de lire cet abonnement';

  @override
  String get errorUnreadableSubscriptionDetail =>
      'Votre abonnement a envoyé un format que cette app ne reconnaît pas. Elle lit les listes de liens en base64, Clash / mihomo, Xray JSON et sing-box. Rien n’a été ajouté.';

  @override
  String get errorEmptySubscriptionTitle => 'Cet abonnement n’a aucun serveur';

  @override
  String errorEmptySubscriptionDetail(String what) {
    return 'Votre abonnement a répondu avec $what qui n’en liste aucun. En général, le compte n’a plus de jours ou sa limite d’appareils est atteinte — demandez-leur.';
  }

  @override
  String errorNoRunnableServersTitle(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Aucun des $total serveurs ne peut fonctionner ici',
      one: 'Le seul serveur ici ne peut pas fonctionner',
    );
    return '$_temp0';
  }

  @override
  String errorNoRunnableServersDetail(String kinds) {
    return 'Ils utilisent $kinds, que cette app ne sait pas encore exécuter. Rien n’a été ajouté.';
  }

  @override
  String get errorProviderMessageTitle =>
      'Votre abonnement a envoyé un message';

  @override
  String errorProviderMessageDetail(String lines) {
    return '$lines\n\nCe ne sont pas des serveurs : chaque entrée ne mène nulle part, rien n’a donc été ajouté.';
  }

  @override
  String get errorSubjectDefault => 'le serveur';

  @override
  String get errorServerDidNotAnswerTitle => 'Le serveur n’a pas répondu';

  @override
  String errorCouldNotReachDetail(String what) {
    return 'Impossible de joindre $what. Vérifiez votre réseau, ou choisissez un autre serveur.';
  }

  @override
  String get errorSecureConnectionTitle =>
      'Impossible d’établir une connexion sécurisée';

  @override
  String errorCertificateRejectedDetail(String what) {
    return 'Le certificat de $what a été rejeté. Si l’adresse est correcte, le serveur est peut-être mal configuré.';
  }

  @override
  String errorConnectionClosedDetail(String what) {
    return 'La connexion à $what a été fermée.';
  }

  @override
  String get errorWrongCredentialsTitle =>
      'Nom d’utilisateur ou mot de passe incorrect';

  @override
  String get errorWrongCredentialsDetail => 'Vérifiez les deux et réessayez.';

  @override
  String get errorSessionExpiredTitle => 'Session expirée';

  @override
  String errorSessionExpiredDetail(String what) {
    return 'Identifiez-vous de nouveau sur $what.';
  }

  @override
  String get errorAccessBlockedTitle => 'Accès bloqué';

  @override
  String get errorAccessBlockedDetail => 'Le serveur a refusé ce compte.';

  @override
  String get errorNothingAtAddressTitle => 'Rien à cette adresse';

  @override
  String errorNothingAtAddressDetail(String what) {
    return 'Vérifiez le lien — $what n’a aucune configuration pour ce compte.';
  }

  @override
  String get errorServerErrorTitle => 'Le serveur a renvoyé une erreur';

  @override
  String get errorServerErrorDetail =>
      'Rien à corriger de ce côté — réessayez dans quelques minutes.';

  @override
  String get errorServerRefusedTitle => 'Le serveur a refusé la requête';

  @override
  String get errorNotALinkTitle => 'Ce lien ne ressemble à rien de connu';

  @override
  String get errorNotALinkDetail =>
      'Attendu : vless://, vmess://, trojan://, ss:// ou une URL d’abonnement.';

  @override
  String get errorTunnelServiceNotRunningTitle =>
      'Le service du tunnel n’est pas lancé';

  @override
  String get errorTunnelServiceNotRunningDetail =>
      'Anoya l’installe comme service Windows « AnoyaTunnel ». Réinstallez l’app, ou démarrez le service dans Services, puis reconnectez-vous.';

  @override
  String get errorTunnelServiceNotRunningDetailLinux =>
      'Anoya l’installe comme service systemd « anoya-tunnel ». Réinstallez le paquet, ou lancez « sudo systemctl start anoya-tunnel », puis reconnectez-vous.';

  @override
  String get errorTunnelServiceStoppedTitle =>
      'Le service du tunnel s’est arrêté';

  @override
  String get errorTunnelServiceStoppedDetail =>
      'Il redémarre tout seul en quelques secondes — reconnectez-vous. Si cela se répète, le journal du tunnel dans Réglages → Journaux en indique la raison.';

  @override
  String get errorSystemRefusedTunnelTitle =>
      'Le système a refusé de démarrer le tunnel';

  @override
  String get errorSystemRefusedTunnelDetail =>
      'Autorisez le profil VPN dans les réglages système, puis reconnectez-vous.';

  @override
  String get errorSignInNotFinishedTitle => 'L’identification n’a pas abouti';

  @override
  String get errorSignInNotFinishedDetail =>
      'La fenêtre du navigateur a été fermée ou le fournisseur a refusé.';

  @override
  String get errorSomethingWentWrongTitle => 'Un problème est survenu';

  @override
  String get errorSomethingWentWrongDetail =>
      'Les détails sont dans Réglages → Journaux.';

  @override
  String get errorDeviceNotAcceptedTitle =>
      'Votre abonnement n’a pas accepté cet appareil';

  @override
  String get errorDeviceNotAcceptedDetail =>
      'Il exige un identifiant d’appareil que cette app a pourtant envoyé. Contactez le support de votre abonnement.';

  @override
  String errorApiTimeout(String baseUrl) {
    return 'Pas de réponse de $baseUrl — vérifiez l’adresse et le réseau.';
  }

  @override
  String errorApiNetwork(String baseUrl) {
    return 'Impossible de joindre $baseUrl — vérifiez l’adresse et le port, et que le serveur est en ligne.';
  }

  @override
  String errorApiTls(String baseUrl) {
    return 'Erreur TLS avec $baseUrl. Si le serveur fonctionne en HTTP simple, saisissez l’adresse avec « http:// ».';
  }

  @override
  String errorApiRequest(String baseUrl) {
    return 'La requête vers $baseUrl n’a pas pu aboutir — vérifiez l’adresse et réessayez.';
  }

  @override
  String get accountExpiredDetail =>
      'Renouvelez-le depuis votre compte, puis reconnectez-vous.';

  @override
  String get accountLimitedTitle => 'Limite de trafic atteinte';

  @override
  String get accountLimitedDetail =>
      'Le forfait est épuisé jusqu’à son renouvellement.';

  @override
  String get accountDeactivatedTitle => 'Accès désactivé';

  @override
  String get accountDeactivatedDetail =>
      'L’administrateur a désactivé ce compte.';

  @override
  String get accountOnHoldTitle => 'Abonnement pas encore démarré';

  @override
  String get accountOnHoldDetail =>
      'Il commence à la première connexion — réessayez dans un instant.';

  @override
  String accountOtherStateTitle(String state) {
    return 'Le compte est $state';
  }

  @override
  String get accountOtherStateDetail =>
      'La connexion n’est pas autorisée dans cet état.';

  @override
  String get amneziaErrorEmptyAnswerTitle => 'La passerelle n’a rien envoyé';

  @override
  String get amneziaErrorEmptyAnswerDetail =>
      'Elle a répondu sans configuration. Réessayez ; si cela se répète, le support de cet abonnement devra examiner le problème.';

  @override
  String get amneziaErrorCancelledTitle => 'Trop long';

  @override
  String get amneziaErrorCancelledDetail =>
      'La passerelle n’a pas répondu à temps. Vérifiez la connexion et réessayez.';

  @override
  String get amneziaErrorNetworkTitle => 'Impossible de joindre la passerelle';

  @override
  String get amneziaErrorNetworkDetail =>
      'La passerelle n’a pas répondu. C’est généralement le réseau, pas l’abonnement — réessayez dans un instant.';

  @override
  String get amneziaErrorTimeoutTitle => 'Délai de la passerelle dépassé';

  @override
  String get amneziaErrorTimeoutDetail =>
      'Aucune réponse dans le délai imparti. Vérifiez la connexion et réessayez.';

  @override
  String get amneziaErrorSslTitle => 'La connexion n’est pas de confiance';

  @override
  String get amneziaErrorSslDetail =>
      'Quelque chose a interféré avec la connexion sécurisée à la passerelle.';

  @override
  String get amneziaErrorConfigTitle =>
      'Cette version ne peut pas dialoguer avec la passerelle';

  @override
  String get amneziaErrorConfigDetail =>
      'Elle a été compilée sans les identifiants de la passerelle ; les abonnements de ce type y sont donc indisponibles.';

  @override
  String get amneziaErrorDecryptTitle => 'La réponse n’a pas pu être lue';

  @override
  String get amneziaErrorDecryptDetail =>
      'La réponse ne correspond pas à ce que la passerelle aurait dû envoyer — souvent le signe d’un réseau qui intercepte le trafic.';

  @override
  String get amneziaErrorInvalidArgumentTitle =>
      'La requête à la passerelle était malformée';

  @override
  String get amneziaErrorInvalidArgumentDetail =>
      'Un défaut de cette app, pas de l’abonnement. Redémarrer l’app aide ; si cela se répète, le journal dans Réglages → Journaux est ce dont le support a besoin.';

  @override
  String get amneziaErrorRefusedTitle => 'La passerelle a refusé la requête';

  @override
  String amneziaErrorRefusedCodeDetail(int code) {
    return 'La passerelle a répondu avec le code $code.';
  }

  @override
  String amneziaErrorRefusedHttpDetail(int status) {
    return 'La passerelle a répondu HTTP $status.';
  }

  @override
  String get amneziaErrorTooManyRequestsTitle => 'Trop de requêtes';

  @override
  String get amneziaErrorTooManyRequestsDetail =>
      'La passerelle limite cet abonnement. Attendez quelques minutes avant de réessayer.';

  @override
  String get amneziaErrorTrialUsedTitle => 'Essai déjà utilisé';

  @override
  String get amneziaErrorTrialUsedDetail =>
      'Cette adresse a déjà activé un essai.';

  @override
  String get amneziaErrorDeviceLimitDetail =>
      'Cet abonnement est déjà installé sur autant d’appareils qu’il le permet. Retirez-en un de l’abonnement, puis réessayez.';

  @override
  String get amneziaErrorNotFoundTitle => 'Abonnement introuvable';

  @override
  String get amneziaErrorNotFoundDetail =>
      'La passerelle ne reconnaît pas cette clé. Vérifiez qu’elle a été collée en entier.';

  @override
  String get amneziaErrorNewerClientTitle =>
      'La passerelle exige un client plus récent';

  @override
  String get amneziaErrorNewerClientDetail =>
      'La passerelle a refusé cette version de l’app. Cela fonctionnera de nouveau une fois l’app mise à jour.';

  @override
  String get amneziaErrorCaptchaPass =>
      'Résolvez-le dans l’app d’origine de cet abonnement, puis actualisez ici.';

  @override
  String get amneziaErrorCaptchaExpiredTitle => 'Le CAPTCHA a expiré';

  @override
  String get amneziaErrorCaptchaRejectedTitle => 'Le CAPTCHA a été rejeté';

  @override
  String get amneziaErrorCaptchaAskedTitle =>
      'La passerelle demande un CAPTCHA';

  @override
  String amneziaErrorCaptchaAskedDetail(String pass) {
    return 'Cette app ne peut pas l’afficher. $pass';
  }

  @override
  String get amneziaErrorNotActiveTitle => 'Abonnement inactif';

  @override
  String get amneziaErrorNotActiveDetail =>
      'La passerelle n’a aucun abonnement actif pour cette clé.';

  @override
  String get amneziaErrorLostKeyTitle => 'Cet abonnement a perdu sa clé';

  @override
  String get amneziaErrorLostKeyDetail =>
      'Retirez la configuration et ajoutez-la de nouveau.';

  @override
  String get amneziaErrorFreeTierUnsupported =>
      'Cet abonnement est gratuit, et sa passerelle exige un CAPTCHA avant de délivrer une configuration — ce que cette app ne peut pas afficher. Utilisez l’app d’origine, ou ajoutez ici une clé payante.';

  @override
  String get importNotAKeyTitle => 'Ce n’est pas une clé d’abonnement';

  @override
  String get importNotAKeyDetail =>
      'Attendu : une clé vpn:// de votre abonnement.';

  @override
  String importKeyUnsupportedTitle(String name) {
    return '$name n’est pas pris en charge ici';
  }

  @override
  String importImportedName(int count) {
    return 'Importé ($count)';
  }

  @override
  String get importFormatLinks => 'une liste de liens';

  @override
  String get importFormatClash => 'un abonnement Clash / mihomo';

  @override
  String get importFormatXray => 'un abonnement Xray JSON';

  @override
  String get importFormatSingbox => 'un abonnement sing-box';

  @override
  String get importFormatUnknown => 'quelque chose de non reconnu';

  @override
  String importDetectedAmneziaKey(String name) {
    return '$name · clé d’abonnement';
  }

  @override
  String importDetectedServer(String type, String label) {
    return 'Serveur $type · $label';
  }

  @override
  String importDetectedSubscriptionUrl(String host) {
    return 'URL d’abonnement · $host';
  }

  @override
  String importDetectedSingleServer(String label) {
    return 'Serveur · $label';
  }

  @override
  String importDetectedSubscriptionText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '1 serveur',
    );
    return 'Abonnement · $_temp0';
  }

  @override
  String get importUnusableNotSubscriptionKey =>
      'Ce n’est pas une clé d’abonnement';

  @override
  String importUnusableNotSupported(String what) {
    return '$what n’est pas pris en charge';
  }

  @override
  String importUnusableTransportNotSupported(String scheme, String transport) {
    return '$scheme sur $transport n’est pas pris en charge';
  }

  @override
  String importUnusableLinkUnreadable(String scheme) {
    return 'lien $scheme:// illisible';
  }

  @override
  String get importUnusableNotALink => 'Ni un lien ni un abonnement';

  @override
  String get catalogGroupStreaming => 'Streaming';

  @override
  String get catalogGroupMessengers => 'Messageries';

  @override
  String get catalogGroupSocial => 'Réseaux sociaux';

  @override
  String get catalogGroupOther => 'Autres';

  @override
  String proxyGroupUrlTest(int count) {
    return 'Latence la plus faible parmi $count';
  }

  @override
  String proxyGroupFallback(int count) {
    return 'Le premier des $count qui répond · dans l’ordre';
  }

  @override
  String proxyGroupLoadBalance(int count) {
    return 'Réparti sur $count';
  }

  @override
  String proxyGroupRelay(int count) {
    return 'Chaîne de $count';
  }

  @override
  String uiDoneCount(int count) {
    return 'Terminé · $count';
  }

  @override
  String get ruleValuesDomains => 'Domaines';

  @override
  String get ruleValuesKeywords => 'Mots-clés';

  @override
  String get ruleValuesPatterns => 'Motifs';

  @override
  String get ruleValuesSubnets => 'Sous-réseaux';

  @override
  String get ruleValuesProcesses => 'Processus';

  @override
  String get ruleValuesHint =>
      'Un par ligne, ou séparés par des virgules ou des espaces';

  @override
  String get ruleValuesHintLines => 'Un par ligne';

  @override
  String get ruleValuesPaste => 'Coller';

  @override
  String get ruleValuesFromFile => 'Ajouter depuis un fichier…';

  @override
  String ruleValuesCompanion(String type) {
    return 'Enregistré comme règle $type distincte, juste après celle-ci';
  }

  @override
  String ruleValuesDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doublons supprimés',
      one: '1 doublon supprimé',
    );
    return '$_temp0';
  }

  @override
  String ruleValuesUnrecognized(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes non reconnues',
      one: '1 ligne non reconnue',
    );
    return '$_temp0';
  }

  @override
  String ruleValuesBadLine(int line, String reason) {
    return 'ligne $line · $reason';
  }

  @override
  String get ruleValuesNotDomain => 'pas un domaine';

  @override
  String get ruleValuesNotAddress => 'pas une adresse';

  @override
  String ruleValuesNotValid(String type) {
    return 'non valide pour $type';
  }

  @override
  String get ruleCountries => 'Pays';

  @override
  String get ruleCategories => 'Catégories';

  @override
  String ruleSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String ruleCountDomains(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count domaines',
      one: '1 domaine',
    );
    return '$_temp0';
  }

  @override
  String ruleCountKeywords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots-clés',
      one: '1 mot-clé',
    );
    return '$_temp0';
  }

  @override
  String ruleCountPatterns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count motifs',
      one: '1 motif',
    );
    return '$_temp0';
  }

  @override
  String ruleCountSubnets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sous-réseaux',
      one: '1 sous-réseau',
    );
    return '$_temp0';
  }

  @override
  String ruleCountProcesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processus',
      one: '1 processus',
    );
    return '$_temp0';
  }

  @override
  String ruleCountCountries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pays',
      one: '1 pays',
    );
    return '$_temp0';
  }

  @override
  String ruleCountCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories',
      one: '1 catégorie',
    );
    return '$_temp0';
  }

  @override
  String get settingsExcludedApps => 'Apps hors du VPN';

  @override
  String settingsExcludedAppsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '1 app',
      zero: 'Aucune',
    );
    return '$_temp0';
  }

  @override
  String get excludedAppsHint =>
      'Le trafic de ces apps n’entre jamais dans le VPN, et elles ne le voient pas — pour les apps qui refusent de fonctionner avec un VPN, comme les apps bancaires. Uniquement sur ce téléphone.';

  @override
  String get excludedAppsAdd => 'Ajouter des apps…';

  @override
  String get excludedAppsPending => 'S’applique à la reconnexion';

  @override
  String get excludedAppsPendingDetail =>
      'Le tunnel tourne encore avec l’ancienne liste';

  @override
  String get excludedAppsReconnect => 'Reconnecter maintenant';

  @override
  String get appPickerTitle => 'Apps';

  @override
  String get ruleApps => 'Apps';

  @override
  String ruleSummaryApps(String apps) {
    return 'le trafic de $apps';
  }

  @override
  String get noticeChannelProblems => 'Problèmes de connexion';

  @override
  String noticeConnected(String server) {
    return 'Connecté · $server';
  }

  @override
  String get noticeSilentTitle => 'Le serveur ne répond pas';

  @override
  String noticeSilentBody(String server) {
    return 'Rien ne revient par « $server », internet via le VPN ne fonctionne donc pas. Touchez pour choisir un autre serveur.';
  }

  @override
  String get noticeConnectedSilent => 'Connecté · le serveur ne répond pas';

  @override
  String noticeConnectedSilentDetail(String server) {
    return '$server · touchez pour choisir un autre serveur';
  }

  @override
  String get noticeStartFailedTitle => 'Le VPN n’a pas pu démarrer';

  @override
  String get noticeStartFailedBody => 'Ouvrez Anoya pour savoir pourquoi.';

  @override
  String get transferReceive => 'Recevoir depuis un téléphone';

  @override
  String get transferReceiveSubtitle =>
      'Configurations et réglages, via le Wi-Fi';

  @override
  String get transferSend => 'Envoyer vers un autre appareil';

  @override
  String get transferSendSubtitle =>
      'Une télé, un ordinateur ou un nouveau téléphone';

  @override
  String get homeAddConnectionTvSubtitle =>
      'Depuis votre téléphone ou par un lien';

  @override
  String get transferStepOpen => 'Ouvrez Anoya sur votre téléphone';

  @override
  String get transferStepSettings =>
      'Réglages → Envoyer vers un autre appareil';

  @override
  String get transferStepScan => 'Visez ce code avec l’appareil photo';

  @override
  String get transferWaiting => 'En attente du téléphone…';

  @override
  String get transferReceiveNote =>
      'Les deux appareils doivent être sur le même réseau. Le téléphone envoie directement ici, chiffré pour ce code — rien ne passe par un serveur.';

  @override
  String get transferNoNetwork => 'Pas de réseau';

  @override
  String get transferNoNetworkDetail =>
      'Connectez cet appareil au Wi-Fi ou à l’Ethernet. Le code s’affiche dès qu’il a une adresse.';

  @override
  String get transferCouldntListen => 'Impossible de commencer la réception';

  @override
  String transferCouldntListenDetail(String reason) {
    return 'Le système n’a pas laissé Anoya ouvrir un port sur ce réseau : $reason';
  }

  @override
  String transferFrom(String device) {
    return 'De $device';
  }

  @override
  String get transferConfirmNote =>
      'Rien n’est ajouté avant votre confirmation. Une configuration déjà reçue de ce téléphone est mise à jour, pas dupliquée.';

  @override
  String get transferConfirmNoteShort =>
      'Rien n’est ajouté avant votre confirmation.';

  @override
  String transferItemNew(String kind) {
    return '$kind · nouvelle';
  }

  @override
  String transferItemUpdates(String kind) {
    return '$kind · remplace celle d’ici';
  }

  @override
  String get transferKindSelfhosted => 'Auto-hébergé';

  @override
  String get transferKindKey => 'Clé d’abonnement';

  @override
  String get transferSettingsSubtitle =>
      'Routage, DNS, vérification de connexion';

  @override
  String get transferAddFailed => 'Impossible d’ajouter ce qui est arrivé';

  @override
  String get transferSendTitle => 'Envoyer';

  @override
  String get transferScanTitle => 'Scannez l’autre appareil';

  @override
  String get transferScanHint => 'Visez son code avec l’appareil photo';

  @override
  String get transferScanDetail =>
      'Sur la télé ou l’ordinateur : Ajouter une connexion → Recevoir depuis un téléphone';

  @override
  String get transferNotAReceiveCode =>
      'Ce n’est pas un code de l’écran Recevoir d’Anoya';

  @override
  String get transferOnYourNetwork => 'Sur votre réseau';

  @override
  String get transferSameNetworkTitle =>
      'Fonctionne uniquement sur le même réseau';

  @override
  String get transferSameNetworkBody =>
      'Les deux appareils doivent être sur le même Wi-Fi ou réseau filaire — cela ne passe pas par internet.';

  @override
  String get transferVpnHint =>
      'Votre VPN est actif : activez « Réseau local en direct » dans les réglages, ou déconnectez-vous un instant.';

  @override
  String get transferAlso => 'Aussi';

  @override
  String get transferRuleSetsUsedOnly =>
      'Seulement ceux qu’utilisent ces configurations';

  @override
  String get transferSendButton => 'Envoyer';

  @override
  String transferSent(String device) {
    return 'Envoyé. Confirmez sur $device pour l’ajouter.';
  }

  @override
  String transferUnreachable(String device) {
    return 'Impossible de joindre $device';
  }

  @override
  String get transferUnreachableDetail =>
      'Vérifiez que les deux sont sur le même Wi-Fi.';

  @override
  String get transferUnreachableVpn =>
      'Si le VPN est actif ici, activez « Réseau local en direct » dans les réglages, ou déconnectez-vous un instant.';

  @override
  String transferRefused(String device) {
    return '$device affiche maintenant un nouveau code. Scannez-le à nouveau.';
  }

  @override
  String get fileNoPicker => 'Aucune app pour choisir un fichier';

  @override
  String get fileNoPickerDetail =>
      'Collez plutôt le lien, ou recevez la configuration depuis un téléphone.';

  @override
  String get fileAccessDenied => 'Pas d’accès aux fichiers';

  @override
  String get fileAccessDeniedDetail =>
      'Autorisez Anoya à lire le stockage dans les réglages du système, ou collez plutôt le lien.';

  @override
  String get modeCaption => 'Mode';

  @override
  String get modeSubscriptionRules => 'Règles de l’abonnement';

  @override
  String get modeOwnRules => 'Règles personnelles';

  @override
  String get modeSubscriptionRulesNote =>
      'Le trafic suit les règles de l’abonnement. Les sorties de ses groupes de proxys se choisissent sur l’accueil.';

  @override
  String get modeOwnRulesNote =>
      'L’abonnement est une liste de serveurs. Vous en choisissez un sur l’accueil et routez avec vos propres règles.';

  @override
  String get consentTitle => 'Utiliser les règles de l’abonnement ?';

  @override
  String consentBody(String name, int count, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listes de règles',
      one: '1 liste de règles',
    );
    return '$name envoie chaque service par son propre chemin. Pour cela, l’app conserve $_temp0 de $hosts et les met à jour chaque semaine. Sans elles, vous choisissez un serveur et routez avec vos propres règles.';
  }

  @override
  String consentHostsMore(String hosts, int count) {
    return '$hosts et $count autres';
  }

  @override
  String get consentUseRules => 'Utiliser ses règles';

  @override
  String get homeKindSubscriptionRules => 'Abonnement · ses règles';

  @override
  String get homeStateSubscription => 'abonnement';

  @override
  String get proxyGroupsTitle => 'Groupes de proxys';

  @override
  String homeProxyGroupsRest(String server, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes',
      one: '1 groupe',
    );
    return 'Le reste via $server · $_temp0';
  }

  @override
  String homeProxyGroupsDirect(int count) {
    return '$count via le VPN · le reste en direct';
  }

  @override
  String get proxyGroupsEverythingElse => 'Tout le reste';

  @override
  String get proxyGroupsChooseExit => 'Choisir la sortie';

  @override
  String get proxyGroupsSetBySubscription => 'Fixé par l’abonnement';

  @override
  String get proxyGroupsRestDirect =>
      'Tout le reste se connecte en direct, hors du VPN.';

  @override
  String proxyGroupsNotApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de l’abonnement n’ont pas pu être appliquées.',
      one: '1 règle de l’abonnement n’a pas pu être appliquée.',
    );
    return '$_temp0';
  }

  @override
  String proxyGroupsYourChoice(String exit) {
    return '$exit · votre choix';
  }

  @override
  String proxyGroupsWaiting(String exit) {
    return '$exit · attend sa liste';
  }

  @override
  String proxyGroupsDefault(String detail) {
    return 'Par défaut · $detail';
  }

  @override
  String get proxyGroupsFromSubscription => 'De l’abonnement';

  @override
  String get proxyGroupsDirect => 'Direct';

  @override
  String get proxyGroupsOutsideVpn => 'Hors du VPN';

  @override
  String get proxyGroupsDirectOutside => 'Direct, hors du VPN';

  @override
  String get proxyGroupsBlocked => 'Bloqué';

  @override
  String proxyGroupsDownloading(int have, int total) {
    return 'Téléchargement des listes de règles · $have sur $total';
  }

  @override
  String get proxyGroupsDownloadingBody =>
      'Tant qu’une liste n’est pas arrivée, ce qu’elle couvre suit le même chemin que tout le reste.';

  @override
  String routingSetBySubscription(String rules) {
    return 'Fixé par l’abonnement · $rules';
  }

  @override
  String get routingWorksWithOwnRules => 'Fonctionne avec Règles personnelles';

  @override
  String get routingSubscriptionRulesNote =>
      'L’abonnement décide où va le trafic. Passez la configuration en Règles personnelles pour utiliser les vôtres.';

  @override
  String rulesTarget(String type, String target) {
    return '$type → $target';
  }

  @override
  String get advancedSectionDns => 'DNS';

  @override
  String get advancedDnsProtection => 'Protection DNS';

  @override
  String get advancedDnsProtectionSubtitle =>
      'Bloquer les requêtes DNS qui contournent le VPN';

  @override
  String get advancedDnsProtectionNote =>
      'Le système interroge aussi le serveur DNS de votre fournisseur, hors du VPN : le fournisseur peut voir les sites que vous ouvrez. La protection bloque ces requêtes, et avec elles le DNS des autres VPN de cet ordinateur : les réseaux d’entreprise (NetBird, Cisco, OpenVPN) ne s’ouvrent plus par leur nom. Laissez-la désactivée si vous en utilisez un.';

  @override
  String get settingsDnsProtectionOn => 'Protection DNS activée';

  @override
  String get settingsDnsProtectionOff => 'Protection DNS désactivée';

  @override
  String get settingsCheckOn => 'vérification activée';

  @override
  String get settingsCheckOff => 'vérification désactivée';
}
