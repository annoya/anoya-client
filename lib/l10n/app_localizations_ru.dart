// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'VPN';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRemove => 'Убрать';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCopy => 'Копировать';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get commonSettings => 'Настройки';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonDismiss => 'Скрыть';

  @override
  String get commonOn => 'Вкл.';

  @override
  String get commonOff => 'Выкл.';

  @override
  String get commonConnect => 'Подключиться';

  @override
  String get commonDisconnect => 'Отключиться';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonOpen => 'Открыть';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonRename => 'Переименовать';

  @override
  String get commonName => 'Название';

  @override
  String get commonAll => 'ВСЕ';

  @override
  String get commonFavorites => 'ИЗБРАННОЕ';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonJustNow => 'только что';

  @override
  String get settingsSectionConfigurations => 'КОНФИГУРАЦИИ';

  @override
  String get settingsSectionConnection => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get settingsSectionRouting => 'МАРШРУТИЗАЦИЯ';

  @override
  String get settingsSectionGeneral => 'ОБЩИЕ';

  @override
  String get settingsSectionDiagnostics => 'ДИАГНОСТИКА';

  @override
  String get settingsSectionAbout => 'О ПРИЛОЖЕНИИ';

  @override
  String get settingsConfigurations => 'Конфигурации';

  @override
  String settingsConfigurationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count конфигурации',
      many: '$count конфигураций',
      few: '$count конфигурации',
      one: '1 конфигурация',
    );
    return '$_temp0';
  }

  @override
  String get uiNounConfiguration => 'конфигурация';

  @override
  String get settingsAutoConnect => 'Автоподключение';

  @override
  String get settingsAutoConnectSubtitle =>
      'Подключаться при запуске компьютера';

  @override
  String get onDemandTitle => 'По запросу';

  @override
  String get settingsDisconnectOnSleep => 'Отключаться в режиме сна';

  @override
  String get settingsDisconnectOnSleepSubtitle =>
      'Разрывать туннель, когда устройство засыпает';

  @override
  String get settingsAlwaysOnSubtitle =>
      'Системный переключатель — задаётся в настройках Android';

  @override
  String get settingsAdvanced => 'Дополнительно';

  @override
  String get settingsConnectionCheckOn => 'Проверка соединения · вкл.';

  @override
  String get settingsConnectionCheckOff => 'Проверка соединения · выкл.';

  @override
  String get settingsLanDirect => 'Локальная сеть напрямую';

  @override
  String get settingsLanDirectSubtitle => 'Трафик локальной сети идёт мимо VPN';

  @override
  String get ruleSetsTitle => 'Наборы правил';

  @override
  String settingsRuleSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count набора',
      many: '$count наборов',
      few: '$count набора',
      one: '1 набор',
    );
    return '$_temp0';
  }

  @override
  String get settingsDefaultDns => 'DNS по умолчанию';

  @override
  String settingsDefaultDnsSubtitle(String name) {
    return '$name · используется, если конфигурация не задаёт свой';
  }

  @override
  String get settingsDnsCustom => 'Свой…';

  @override
  String get settingsDnsCustomSubtitle =>
      'любой адрес, который принимает движок';

  @override
  String get settingsDnsResolverLabel => 'Резолвер';

  @override
  String get settingsDnsUseCloudflare => 'Использовать Cloudflare';

  @override
  String settingsGeoDownloaded(String size) {
    return 'загружено · $size';
  }

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsThemeSystemSubtitle => 'Следовать настройке устройства';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String aboutVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get aboutEngine => 'Движок';

  @override
  String get aboutVersionCopied => 'Версия скопирована';

  @override
  String get aboutTermsOfService => 'Условия использования';

  @override
  String get aboutPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get aboutNotPublishedYet => 'Ещё не опубликовано';

  @override
  String get uiCouldNotOpenPage => 'Не удалось открыть страницу.';

  @override
  String get advancedSectionConnectionCheck => 'ПРОВЕРКА СОЕДИНЕНИЯ';

  @override
  String get advancedSectionLastCheck => 'ПОСЛЕДНЯЯ ПРОВЕРКА';

  @override
  String get advancedCheckAfterConnecting => 'Проверять после подключения';

  @override
  String get advancedCheckAfterConnectingSubtitle =>
      'Загрузить страницу через сервер и замерить время ответа';

  @override
  String get advancedTestUrl => 'Тестовый URL';

  @override
  String get advancedUrlLabel => 'URL';

  @override
  String get advancedUseDefault => 'По умолчанию';

  @override
  String get advancedInvalidUrl =>
      'Введите адрес, начинающийся с http:// или https://.';

  @override
  String get advancedGiveUpAfter => 'Ждать не дольше';

  @override
  String advancedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунды',
      many: '$count секунд',
      few: '$count секунды',
      one: '1 секунда',
    );
    return '$_temp0';
  }

  @override
  String get advancedTestNow => 'Проверить сейчас';

  @override
  String get advancedNeedsTunnelNote =>
      'Запрос идёт через работающий движок, поэтому для проверки туннель должен быть поднят.';

  @override
  String get advancedCheckScopeNote =>
      'Запрос идёт через сам сервер, так что правила маршрутизации на него не влияют. Проверка показывает, что сервер пропускает трафик, — но не то, что ваш трафик идёт через него.';

  @override
  String get advancedNoAnswer => 'Нет ответа';

  @override
  String advancedNoAnswerDetail(String failure) {
    return '$failure Туннель поднят, значит дело в сервере или в сети за ним.';
  }

  @override
  String get advancedTrafficGettingThrough => 'Трафик проходит';

  @override
  String advancedAnsweredIn(int ms) {
    return 'Ответ за $ms мс';
  }

  @override
  String advancedResultVia(String ago, String via) {
    return '$ago · через $via';
  }

  @override
  String commonMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String advancedHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String get alwaysOnTitle => 'Постоянный VPN';

  @override
  String get alwaysOnStartedBySystem => 'Запускается системой';

  @override
  String get alwaysOnStartedBySystemSubtitle =>
      'При загрузке и каждый раз, когда туннель обрывается';

  @override
  String get alwaysOnBlockWithoutVpn => 'Блокировать соединения без VPN';

  @override
  String get alwaysOnBlockWithoutVpnSubtitle =>
      'Системный kill switch, на том же экране';

  @override
  String get alwaysOnNote =>
      'Этим переключателем управляет Android, поэтому он находится в системных настройках: Сеть и интернет → VPN → шестерёнка рядом с этим приложением. Система запускает конфигурацию, которая использовалась последней.';

  @override
  String get alwaysOnOpenSystemSettings => 'Открыть системные настройки VPN';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get dnsSectionInEffect => 'ДЕЙСТВУЮТ';

  @override
  String get dnsSectionDropped => 'ОТБРОШЕНЫ';

  @override
  String get dnsParallelNote =>
      'Опрашиваются одновременно; побеждает первый ответ.';

  @override
  String get dnsFallbackNote =>
      'Эта конфигурация не задаёт свой резолвер, поэтому приложение использует резолвер по умолчанию — его можно сменить в Настройки › DNS по умолчанию.';

  @override
  String get dnsProviderNote =>
      'Выбран тем, кто настроил эту конфигурацию, и меняется вместе с ней.';

  @override
  String get dnsProxyResolvedDirectlyNote =>
      'Адрес сервера, через который вы подключаетесь, всегда резолвится напрямую. Иначе никак — до туннеля было бы не добраться.';

  @override
  String dnsResolverSubtitle(String protocol, String origin) {
    return '$protocol · $origin';
  }

  @override
  String get dnsPinIgnoredTooltip =>
      'Конфигурация запросила исходящее соединение, которого это приложение не создаёт, поэтому запрос отброшен, а резолвер доступен напрямую.';

  @override
  String get dnsOriginAppDefault => 'по умолчанию в приложении';

  @override
  String get dnsOriginSubscription => 'из вашей подписки';

  @override
  String get dnsOriginOrganisation => 'от вашей организации';

  @override
  String get dnsOriginConfiguration => 'из этой конфигурации';

  @override
  String get dnsRoutingDirect => 'напрямую';

  @override
  String get dnsRoutingFollowsRules => 'по вашим правилам';

  @override
  String get dnsRoutingThroughTunnel => 'через туннель';

  @override
  String get dnsProtocolDoh => 'DNS over HTTPS';

  @override
  String get dnsProtocolDot => 'DNS over TLS';

  @override
  String get dnsProtocolDoq => 'DNS over QUIC';

  @override
  String get dnsProtocolPlain => 'Обычный, без шифрования';

  @override
  String get dnsDropMalformed =>
      'Это не адрес резолвера. Ничего из подписки не попадает в конфигурацию движка без проверки.';

  @override
  String get dnsDropUnknownScheme =>
      'Движок не знает такой схемы. Если бы строку оставили, отказала бы вся конфигурация, а не только эта запись.';

  @override
  String get dnsDropCannotCarry =>
      'Обычный DNS не может пройти через этот сервер, а отправлять его вне туннеля — значит показать вашей сети каждый сайт, на который вы заходите.';

  @override
  String dnsDropTooMany(int max) {
    return 'Сверх $max, которые получает движок. Он опрашивает их все сразу, поэтому длинный список лишь замедляет ответ, не улучшая его.';
  }

  @override
  String get dnsPresetQuad9Note => 'фильтрует известные вредоносные домены';

  @override
  String get dnsPresetAdGuardNote => 'фильтрует рекламу и трекеры';

  @override
  String get dnsErrorNotResolverAddress => 'Это не адрес резолвера.';

  @override
  String get dnsErrorAddressedByName =>
      'Задан по имени — его пришлось бы резолвить, прежде чем он смог бы резолвить что-либо сам. Укажите его IP-адрес.';

  @override
  String get geoTitle => 'GeoIP и GeoSite';

  @override
  String get geoSectionDatabases => 'БАЗЫ ДАННЫХ';

  @override
  String get geoSectionUpdates => 'ОБНОВЛЕНИЯ';

  @override
  String get geoGeoipSource => 'Источник GeoIP';

  @override
  String get geoGeositeSource => 'Источник GeoSite';

  @override
  String get geoDownloadUrlLabel => 'URL для загрузки';

  @override
  String get geoResetToDefault => 'Сбросить по умолчанию';

  @override
  String get geoNotDownloaded => 'не загружено';

  @override
  String get geoNever => 'никогда';

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '1 день назад',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа назад',
      many: '$count часов назад',
      few: '$count часа назад',
      one: '1 час назад',
    );
    return '$_temp0';
  }

  @override
  String get geoLastUpdated => 'Последнее обновление';

  @override
  String get geoAutoUpdate => 'Автообновление';

  @override
  String get geoAutoUpdateSubtitle => 'Раз в неделю, если базы уже загружены';

  @override
  String get geoUpdateNow => 'Обновить сейчас';

  @override
  String get geoDownload => 'Загрузить (~25 МБ)';

  @override
  String get geoDatabaseHostSubject => 'сервер с базами данных';

  @override
  String get geositeCategoryLabel => 'Категория';

  @override
  String geositeDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count домена',
      many: '$count доменов',
      few: '$count домена',
      one: '1 домен',
    );
    return '$_temp0';
  }

  @override
  String get geositeNoCategories =>
      'Категорий нет — сначала загрузите гео-базы.';

  @override
  String uiNothingMatches(String query) {
    return 'По запросу «$query» ничего не найдено.';
  }

  @override
  String get geositeSectionPopular => 'ПОПУЛЯРНЫЕ';

  @override
  String geositeSectionAll(int count) {
    return 'ВСЕ · $count';
  }

  @override
  String geositeSectionAllMatch(int count, int total) {
    return 'ВСЕ · СОВПАДАЮТ $count ИЗ $total';
  }

  @override
  String get logsTitle => 'Журналы';

  @override
  String get logsSectionCollection => 'СБОР';

  @override
  String get logsSectionTunnel => 'ТУННЕЛЬ';

  @override
  String get logsSectionApp => 'ПРИЛОЖЕНИЕ';

  @override
  String get logsCollect => 'Собирать журналы';

  @override
  String get logsCollectSubtitle =>
      'Выкл.: приложение, туннель и ядро перестают писать. Существующие файлы остаются доступны для чтения.';

  @override
  String get logsTunnel => 'Туннель';

  @override
  String get logsTunnelSubtitle => 'События Network Extension';

  @override
  String get logsCore => 'Ядро (mihomo)';

  @override
  String get logsCoreSubtitle =>
      'Журнал движка: соединения, DNS, маршрутизация';

  @override
  String get logsApplication => 'Приложение';

  @override
  String get logsApplicationSubtitle => 'События на стороне клиента';

  @override
  String get logsSaveAllZip => 'Сохранить все журналы (.zip)';

  @override
  String get logsSaveAll => 'Сохранить все журналы';

  @override
  String get logsSaveToFile => 'Сохранить в файл…';

  @override
  String get logsSaveToFileSubtitle => 'Выбрать папку на этом устройстве';

  @override
  String get logsShare => 'Поделиться…';

  @override
  String get logsShareSubtitle => 'Отправить архив куда-нибудь';

  @override
  String get logsSaveDialogTitle => 'Сохранить журналы';

  @override
  String logsSavedTo(String path) {
    return 'Сохранено в $path';
  }

  @override
  String get logsClearAll => 'Очистить все журналы';

  @override
  String get logsClearAllQuestion => 'Очистить все журналы?';

  @override
  String get logsClearAllContent =>
      'Журналы приложения, туннеля и ядра будут удалены с этого устройства. Журналы туннеля и ядра можно очистить только при подключённом VPN.';

  @override
  String get logsCleared => 'Журналы очищены.';

  @override
  String get logsAppLogClearedOnly =>
      'Журнал приложения очищен. Для журналов туннеля и ядра нужен подключённый VPN.';

  @override
  String get logsNoLog => 'Журнала нет.';

  @override
  String get logsNoLogYet => 'Журнала пока нет.';

  @override
  String get logsEmpty => 'Пусто';

  @override
  String get logsUnavailable =>
      'Журналы доступны только пока работает туннель.\n(Процесс туннеля хранит журналы у себя и передаёт их приложению по IPC.)';

  @override
  String get commonTryAgain => 'Попробовать снова';

  @override
  String configKindSelfhosted(String servers) {
    return 'Свой сервер · $servers';
  }

  @override
  String configKindSubscription(String servers, String groups) {
    return 'Подписка · $servers$groups';
  }

  @override
  String get configKindSubscriptionPlain => 'Подписка';

  @override
  String get configKindSingleServer => 'Один сервер';

  @override
  String commonServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сервера',
      many: '$count серверов',
      few: '$count сервера',
      one: '1 сервер',
    );
    return '$_temp0';
  }

  @override
  String configServersOfOffered(int ours, int offered) {
    String _temp0 = intl.Intl.pluralLogic(
      offered,
      locale: localeName,
      other: '$ours из $offered серверов',
      many: '$ours из $offered серверов',
      few: '$ours из $offered серверов',
      one: '$ours из 1 сервера',
    );
    return '$_temp0';
  }

  @override
  String configGroupsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count группы',
      many: ' · $count групп',
      few: ' · $count группы',
      one: ' · 1 группа',
    );
    return '$_temp0';
  }

  @override
  String get configSource => 'Источник';

  @override
  String get configSourceViaFallback =>
      'При последнем обновлении использовался резервный адрес подписки';

  @override
  String get configCouldNotOpenLink => 'Не удалось открыть ссылку.';

  @override
  String get configLinkCopied => 'Ссылка скопирована';

  @override
  String configUnsupportedTitle(int skipped, int offered) {
    return '$skipped из $offered серверов не поддерживаются';
  }

  @override
  String configUnsupportedDetail(String kinds, int available) {
    return 'Они используют $kinds, а это приложение пока такого не умеет. Остальные $available доступны.';
  }

  @override
  String get configSetActive => 'Сделать активной';

  @override
  String get configRemoveConfiguration => 'Удалить конфигурацию';

  @override
  String configRemoveTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String get configRemoveDetail =>
      'Конфигурация будет удалена с этого устройства.';

  @override
  String get configSectionSubscription => 'ПОДПИСКА';

  @override
  String get configRanUntil => 'Действовала до';

  @override
  String get configRunsUntil => 'Действует до';

  @override
  String get configDevices => 'Устройства';

  @override
  String configDevicesUsed(int active, int max) {
    return '$active из $max занято';
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
      other: 'осталось $count дня',
      many: 'осталось $count дней',
      few: 'осталось $count дня',
      one: 'остался 1 день',
    );
    return '$date · $_temp0';
  }

  @override
  String get accountExpiredTitle => 'Подписка истекла';

  @override
  String get configSubscriptionExpiredDetail =>
      'Продлите подписку, затем обновите эту конфигурацию.';

  @override
  String get configSectionThisDevice => 'ЭТО УСТРОЙСТВО';

  @override
  String get configDeviceIdentifiedSubtitle =>
      'Известно вашей подписке, которая считает устройства';

  @override
  String get configDeviceId => 'ID устройства';

  @override
  String get configDeviceHintAmnezia =>
      'Ваша подписка считает устройства по этому id. Он создаётся один раз и сохраняется, поэтому переподключение не занимает новый слот — а переустановка занимает.';

  @override
  String get configDeviceHintPanel =>
      'Ваша подписка считает устройства по id, который это приложение создаёт один раз и сохраняет. После переустановки создаётся новый, и он занимает ещё один слот.';

  @override
  String configCopiedTitle(String title) {
    return '$title скопирован';
  }

  @override
  String configDnsSummary(String host, String routing) {
    return '$host · $routing';
  }

  @override
  String configDnsMore(int count) {
    return ' · ещё $count';
  }

  @override
  String configDnsDropped(int count) {
    return '$count отброшено';
  }

  @override
  String get configDnsByApp => 'DNS от приложения';

  @override
  String configDnsOrigin(String origin) {
    return 'DNS $origin';
  }

  @override
  String configDnsRefused(int count) {
    return 'DNS: отклонено $count';
  }

  @override
  String get configRouting => 'Маршрутизация';

  @override
  String get configRuleSet => 'Набор правил';

  @override
  String get configRuleSetDefault => 'Стандартный';

  @override
  String get configRuleLists => 'Списки правил';

  @override
  String get ruleSetModeSplit => 'Раздельный';

  @override
  String get ruleSetModeFull => 'Полный туннель';

  @override
  String ruleSetSummary(String mode, String rules) {
    return '$mode · $rules';
  }

  @override
  String get ruleSetNoRules => 'нет правил';

  @override
  String get configNoExceptions => 'без исключений';

  @override
  String configRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count правила',
      many: '$count правил',
      few: '$count правила',
      one: '1 правило',
    );
    return '$_temp0';
  }

  @override
  String configSkippedNotSupported(int count) {
    return '$count не поддерживается';
  }

  @override
  String configListsUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count списка недоступны',
      many: '$count списков недоступны',
      few: '$count списка недоступны',
      one: '1 список недоступен',
    );
    return '$_temp0';
  }

  @override
  String configRulesNeedLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count требуют свои списки',
      many: '$count требуют свои списки',
      few: '$count требуют свои списки',
      one: '1 требует свои списки',
    );
    return '$_temp0';
  }

  @override
  String configDownloadingLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Загружаются $count списка…',
      many: 'Загружаются $count списков…',
      few: 'Загружаются $count списка…',
      one: 'Загружается один список…',
    );
    return '$_temp0';
  }

  @override
  String configRuleListsOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count правилам они нужны',
      many: '$count правилам они нужны',
      few: '$count правилам они нужны',
      one: '1 правилу они нужны',
    );
    return 'Выкл. · $_temp0';
  }

  @override
  String get configChecking => 'Проверка…';

  @override
  String get configNoneDownloadedYet => 'Пока ничего не загружено';

  @override
  String configListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count списка',
      many: '$count списков',
      few: '$count списка',
      one: '1 список',
    );
    return '$_temp0';
  }

  @override
  String configListsDownloadedOf(int have, int total) {
    return '$have из $total загружено';
  }

  @override
  String configListsSize(String count, int kb) {
    return '$count · $kb КБ';
  }

  @override
  String configListsFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось загрузить $count списка',
      many: 'Не удалось загрузить $count списков',
      few: 'Не удалось загрузить $count списка',
      one: 'Не удалось загрузить один список',
    );
    return '$_temp0';
  }

  @override
  String configListsFailedDetail(int count, String names, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names с $hosts — правила, которые их используют, не применяются.',
      many: '$names с $hosts — правила, которые их используют, не применяются.',
      few: '$names с $hosts — правила, которые их используют, не применяются.',
      one: '$names с $hosts — правило, которое его использует, не применяется.',
    );
    return '$_temp0';
  }

  @override
  String configReplacedBy(String name) {
    return 'Заменён: $name';
  }

  @override
  String get configRoutingOffSummary => 'Выкл. · всё через VPN';

  @override
  String get configManagedByOrganization => 'Управляется вашей организацией';

  @override
  String configManagedSummary(String mode, int count) {
    return '$mode · $count правил, заданы на сервере';
  }

  @override
  String configSetByOrganization(String mode) {
    return '$mode · задано вашей организацией';
  }

  @override
  String get configSectionOrganizationRouting => 'МАРШРУТИЗАЦИЯ ОРГАНИЗАЦИИ';

  @override
  String get configSectionSubscriptionRouting => 'МАРШРУТИЗАЦИЯ ПОДПИСКИ';

  @override
  String get configSectionDeviceRouting => 'МАРШРУТИЗАЦИЯ УСТРОЙСТВА';

  @override
  String get configOrganizationRoutingNote =>
      'Эту политику задаёт и применяет ваша организация. Здесь её можно посмотреть; изменения делаются на их стороне.';

  @override
  String get configSubscriptionRoutes => 'маршруты подписки';

  @override
  String get configSubscriptionRoutingNote =>
      'Выключите переключатель, чтобы использовать свой набор правил. Подписка не может навязать этот выбор ни в ту, ни в другую сторону.';

  @override
  String get configDeviceRoutingNote =>
      'Наборы правил общие для всех конфигураций; переключатель — у каждой свой, так что рабочая и личная подписки могут использовать один набор по-разному.';

  @override
  String get configSectionDetails => 'ПОДРОБНОСТИ';

  @override
  String get configGetSupport => 'Обратиться в поддержку';

  @override
  String get configNoPlanDetails =>
      'Подписка не сообщила подробностей о тарифе.';

  @override
  String configUsedNoLimit(String used) {
    return 'Использовано $used · без лимита';
  }

  @override
  String configTrafficOf(String used, String total) {
    return 'Трафик: $used из $total';
  }

  @override
  String get configNoExpiryDate => 'Дата окончания не указана';

  @override
  String configExpiredOn(String date) {
    return 'Истекла $date';
  }

  @override
  String configActiveUntil(String date) {
    return 'Активна до $date';
  }

  @override
  String configPlanLine(String when) {
    return '$when · по данным подписки, здесь не проверяется';
  }

  @override
  String get configAccount => 'Аккаунт';

  @override
  String configStatus(String status) {
    return 'Статус: $status';
  }

  @override
  String configStatusOnHold(String status) {
    return 'Статус: $status · начнётся при первом использовании';
  }

  @override
  String configStatusExpires(String status, String date) {
    return 'Статус: $status · истекает $date';
  }

  @override
  String get configLastRefreshed => 'Последнее обновление';

  @override
  String get configRefreshEvery => 'Обновлять каждые';

  @override
  String get configHours => 'Часы';

  @override
  String get configRefreshAsSubscriptionAsks => 'Как просит подписка';

  @override
  String get configRefreshEnterWholeHours => 'Введите целое число часов.';

  @override
  String configRefreshNever(String every) {
    return 'никогда · $every';
  }

  @override
  String configRefreshAgo(String ago, String every) {
    return '$ago · $every';
  }

  @override
  String configAutoEveryMinutes(int count) {
    return 'авто каждые $count мин';
  }

  @override
  String configAutoEveryHours(int count) {
    return 'авто каждые $count ч';
  }

  @override
  String configAutoEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'авто каждые $count дня',
      many: 'авто каждые $count дней',
      few: 'авто каждые $count дня',
      one: 'авто каждый день',
    );
    return '$_temp0';
  }

  @override
  String get configRefreshNow => 'Обновить сейчас';

  @override
  String configRefreshFailed(String detail) {
    return 'Не удалось обновить — $detail';
  }

  @override
  String get configRefreshFailedFallback =>
      'показаны серверы, которые уже есть.';

  @override
  String get configOrganizationPolicyDetail =>
      'Эти правила заданы на сервере, здесь их изменить нельзя.';

  @override
  String configSentBy(String name) {
    return 'Отправитель: $name';
  }

  @override
  String get configProviderPolicyDetail =>
      'Только чтение. Обновление подписки заменяет их.';

  @override
  String configProviderPolicyDetailSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ещё $count правила не удалось перевести для этого приложения, они не применяются.',
      many:
          'Ещё $count правил не удалось перевести для этого приложения, они не применяются.',
      few:
          'Ещё $count правила не удалось перевести для этого приложения, они не применяются.',
      one:
          'Ещё 1 правило не удалось перевести для этого приложения, оно не применяется.',
    );
    return 'Только чтение. Обновление подписки заменяет их. $_temp0';
  }

  @override
  String get ruleSetSplitTunneling => 'Раздельное туннелирование';

  @override
  String get ruleSetGeoNotDownloaded => 'Гео-базы не загружены';

  @override
  String get ruleSetGeoNotDownloadedDetail =>
      'правила geoip / geosite неактивны, пока их нет (~25 МБ)';

  @override
  String get ruleSetRulesHeader => 'ПРАВИЛА — ПРИМЕНЯЕТСЯ ПЕРВОЕ СОВПАВШЕЕ';

  @override
  String get homeAddConfiguration => 'Добавить конфигурацию';

  @override
  String get homeConfigurationSettings => 'Настройки конфигурации';

  @override
  String homeChipAuto(String state) {
    return 'Авто · $state';
  }

  @override
  String homeChipRouting(String state) {
    return 'Маршрутизация · $state';
  }

  @override
  String homeChipLogs(String state) {
    return 'Журналы · $state';
  }

  @override
  String get homeStateOn => 'вкл.';

  @override
  String get homeStateOff => 'выкл.';

  @override
  String get homeAutoPaused => 'пауза';

  @override
  String get homeAutoNotArmed => 'не активировано';

  @override
  String get homeCheckFailedTitle => 'Подключено, но ответа нет';

  @override
  String get homeCheckFailedDetail =>
      'Проверка через этот сервер не получила ответа. Попробуйте другой или откройте «Дополнительно».';

  @override
  String get homeAutoConnectPausedTitle => 'Автоподключение приостановлено';

  @override
  String get homeAutoConnectPausedDetail =>
      'Нажмите «Подключиться», чтобы включить его снова';

  @override
  String get homeAutoConnectNotArmedTitle =>
      'Автоподключение ещё не активировано';

  @override
  String get homeAutoConnectNotArmedDetail =>
      'Подключитесь один раз, чтобы система взяла управление на себя';

  @override
  String get homeNoServers => 'Нет серверов';

  @override
  String get homeGroupAuto => 'авто';

  @override
  String homeGroupAutoPicked(String server) {
    return 'авто · $server';
  }

  @override
  String homeAccountUntil(String status, String until) {
    return '$status · до $until';
  }

  @override
  String get homeConfiguration => 'Конфигурация';

  @override
  String get homeServer => 'Сервер';

  @override
  String get homeChosenByEngine => 'ВЫБИРАЕТ ДВИЖОК';

  @override
  String get homeSwitchingServer => 'Смена сервера…';

  @override
  String get homeGettingServer => 'Получение сервера…';

  @override
  String get statusConnected => 'Подключено';

  @override
  String homeConnectedClock(String clock) {
    return 'Подключено · $clock';
  }

  @override
  String homeStatusAuto(String status) {
    return '$status · авто';
  }

  @override
  String get statusConnecting => 'Подключение…';

  @override
  String get statusError => 'Ошибка';

  @override
  String get statusNotConnected => 'Не подключено';

  @override
  String homeGroupRechecks(String summary, int minutes) {
    return '$summary · перепроверка каждые $minutes мин';
  }

  @override
  String get startCouldntReadFile => 'Не удалось прочитать файл';

  @override
  String get startCouldntReadFileDetail =>
      'Попробуйте открыть его ещё раз или вставьте его содержимое.';

  @override
  String get startAddConnection => 'Добавить подключение';

  @override
  String get startSubtitle => 'Ссылка, подписка или файл конфигурации';

  @override
  String get startLinkLabel => 'Ссылка или подписка';

  @override
  String get startLinkHint => 'vless://…  или  https://…/sub';

  @override
  String get startPaste => 'Вставить';

  @override
  String get startClipboardEmpty => 'Буфер обмена пуст';

  @override
  String startCantUseThis(String reason) {
    return 'Не подходит · $reason';
  }

  @override
  String get startOpenConfigFile => 'Открыть файл конфигурации…';

  @override
  String get startOr => 'или';

  @override
  String get startSignInToServer => 'Войти на свой сервер';

  @override
  String get startOpenSubscriptionPage => 'Открыть страницу подписки';

  @override
  String get signInEnterServerFirst => 'Сначала введите адрес сервера';

  @override
  String get signInNoSsoProviders => 'У этого сервера нет SSO-провайдеров';

  @override
  String get signInNoSsoProvidersDetail =>
      'Войдите по имени пользователя и паролю.';

  @override
  String get signInWith => 'Войти через';

  @override
  String get signIn => 'Войти';

  @override
  String get signInSubtitle => 'Сервер вашей организации или ваш личный';

  @override
  String get signInServerAddress => 'Адрес сервера';

  @override
  String get signInServerHint => 'https://your-server';

  @override
  String get signInUsername => 'Имя пользователя';

  @override
  String get signInPassword => 'Пароль';

  @override
  String get signInWithSso => 'Войти через SSO';

  @override
  String get uiNounItem => 'элемент';

  @override
  String get uiNounServer => 'сервер';

  @override
  String get uiNounCountry => 'страна';

  @override
  String get uiRemoveFromFavorites => 'Убрать из избранного';

  @override
  String get uiAddToFavorites => 'В избранное';

  @override
  String get uiAllNothingMatches => 'ВСЕ · НИЧЕГО НЕ НАЙДЕНО';

  @override
  String uiAllMatchCount(int shown, int total) {
    return 'ВСЕ · СОВПАДАЮТ $shown ИЗ $total';
  }

  @override
  String uiNoMatches(String noun, String query, int total) {
    return 'Ни один $noun не совпадает с «$query». Очистите поиск, чтобы увидеть все $total.';
  }

  @override
  String get ruleSetModeFullDescription =>
      'Весь трафик идёт через VPN; правила задают исключения.';

  @override
  String get ruleSetModeSplitDescription =>
      'Через VPN идёт только трафик, подходящий под правила; остальной идёт напрямую.';

  @override
  String get ruleSetNoRulesSplit =>
      'Правил нет: через VPN не идёт ничего. Добавьте правила для того, что нужно туннелировать.';

  @override
  String get ruleSetNoRulesFull => 'Правил нет: весь трафик идёт через VPN.';

  @override
  String get ruleSetDownload => 'Загрузить';

  @override
  String get ruleKindRuleList => 'список правил';

  @override
  String ruleInactiveNoDatabase(String kind) {
    return '$kind · неактивно — нет базы';
  }

  @override
  String ruleInactiveDesktopOnly(String kind) {
    return '$kind · неактивно — только на компьютере';
  }

  @override
  String ruleInactiveListsOff(String kind) {
    return '$kind · неактивно — списки выключены';
  }

  @override
  String ruleInactiveNotDownloaded(String kind) {
    return '$kind · неактивно — не загружено';
  }

  @override
  String ruleNoResolveKind(String kind) {
    return '$kind · no-resolve';
  }

  @override
  String get ruleTypeDomainSuffix => 'домен и поддомены';

  @override
  String get ruleTypeDomainKeyword => 'домен содержит';

  @override
  String get ruleTypeDomainExact => 'точный домен';

  @override
  String get ruleTypeIpCidr => 'диапазон IP';

  @override
  String get ruleTypeProcessName => 'приложение по имени';

  @override
  String get ruleTypeGeoip => 'страна по IP';

  @override
  String get ruleTypeGeosite => 'списки доменов';

  @override
  String get ruleTypeDomainRegex => 'домен по шаблону';

  @override
  String get ruleTypeRuleList => 'список из вашей подписки';

  @override
  String get rulePickCountry => 'Выберите страну.';

  @override
  String ruleInvalidValue(String type) {
    return 'Недопустимое значение для типа «$type».';
  }

  @override
  String get ruleMatch => 'Условие';

  @override
  String get ruleNotAvailableOnPlatform => 'недоступно на этой платформе';

  @override
  String get ruleNeedsGeoDatabases => 'нужны гео-базы';

  @override
  String get ruleAction => 'Действие';

  @override
  String get ruleActionProxyDescription => 'через VPN';

  @override
  String get ruleActionDirectDescription => 'мимо VPN';

  @override
  String get ruleActionBlockDescription => 'разорвать соединение';

  @override
  String get ruleAdd => 'Добавить правило';

  @override
  String get ruleEdit => 'Изменить правило';

  @override
  String get ruleCountry => 'Страна';

  @override
  String get ruleChoose => 'Выбрать…';

  @override
  String get ruleNoResolveDescription =>
      'Только соединения по IP, без резолвинга доменов';

  @override
  String get ruleValue => 'Значение';

  @override
  String ruleSummaryGeoip(String country) {
    return 'трафик к IP-адресам в $country';
  }

  @override
  String ruleSummaryGeosite(String category) {
    return 'домены «$category» (список GeoSite)';
  }

  @override
  String ruleSummaryProcess(String name) {
    return 'трафик «$name»';
  }

  @override
  String ruleSummaryMatching(String value) {
    return 'трафик, подходящий под $value';
  }

  @override
  String get ruleSummaryProxy => 'идёт через VPN';

  @override
  String get ruleSummaryDirect => 'идёт напрямую, мимо VPN';

  @override
  String get ruleSummaryBlock => 'блокируется';

  @override
  String ruleSummary(String target, String verb) {
    return '→ $target $verb.';
  }

  @override
  String ruleSetDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get ruleSetDeleteBody =>
      'Конфигурации с этим набором перейдут на стандартный.';

  @override
  String get ruleSetDeleteTooltip => 'Удалить набор правил';

  @override
  String get ruleSetSimple => 'Простой';

  @override
  String get ruleSetDownloadSiteLists => 'Сначала загрузите списки сайтов';

  @override
  String get ruleSetDownloadSiteListsDetail =>
      'Для выбора сервисов нужны гео-базы (~25 МБ, один раз)';

  @override
  String ruleSetAdvancedRules(int count) {
    return 'Расширенные правила · $count';
  }

  @override
  String get ruleSetAdvancedRulesDetail =>
      'Применяются раньше списка ниже · редактируются в «Дополнительно»';

  @override
  String get ruleSetSearchServices => 'Поиск сервисов';

  @override
  String get ruleSetCountriesHeader => 'СТРАНЫ';

  @override
  String get ruleSetAddCountry => 'Добавить страну';

  @override
  String get ruleSetServicesHeader => 'СЕРВИСЫ';

  @override
  String get ruleSetAddCategory => 'Добавить категорию';

  @override
  String get ruleSetOtherCategoriesHeader => 'ДРУГИЕ КАТЕГОРИИ';

  @override
  String get ruleSetNothingSelectedSplit =>
      'Ничего не выбрано · через VPN пока ничего не идёт';

  @override
  String get ruleSetNothingSelectedFull =>
      'Ничего не выбрано · всё идёт через VPN';

  @override
  String ruleSetSelectedSplit(int count) {
    return 'Выбрано $count · всё остальное идёт напрямую';
  }

  @override
  String ruleSetSelectedFull(int count) {
    return 'Выбрано $count · они идут напрямую, остальное через VPN';
  }

  @override
  String get ruleSetOnlySelected => 'Только выбранные';

  @override
  String get ruleSetAllExceptSelected => 'Всё, кроме выбранных';

  @override
  String get ruleSetOnlySelectedDescription =>
      'Через VPN идут только выбранные сервисы. Всё остальное подключается напрямую.';

  @override
  String get ruleSetAllExceptSelectedDescription =>
      'Всё идёт через VPN. Выбранные сервисы подключаются напрямую.';

  @override
  String get ruleSetNew => 'Новый набор правил';

  @override
  String get ruleSetNameHint => 'Работа';

  @override
  String get ruleSetCreate => 'Создать';

  @override
  String ruleSetRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count правила',
      many: '$count правил',
      few: '$count правила',
      one: '1 правило',
      zero: 'нет правил',
    );
    return '$_temp0';
  }

  @override
  String ruleSetUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'используется $count конфигурациями',
      many: 'используется $count конфигурациями',
      few: 'используется $count конфигурациями',
      one: 'используется 1 конфигурацией',
    );
    return '$_temp0';
  }

  @override
  String ruleSetSummaryUsed(String mode, String rules, String used) {
    return '$mode · $rules · $used';
  }

  @override
  String get onDemandEnable => 'Включить «по запросу»';

  @override
  String get onDemandEnableSubtitle =>
      'Система применяет первое совпавшее правило';

  @override
  String get onDemandNoRules =>
      'Правил нет. При включении добавится правило «Подключаться · Любая сеть».';

  @override
  String get onDemandRulesFootnote =>
      'Правила проверяются сверху вниз. Если ни одно не совпало, туннель остаётся как есть.';

  @override
  String get onDemandTagConnect => 'ПОДКЛ.';

  @override
  String get onDemandTagDisconnect => 'ОТКЛ.';

  @override
  String get onDemandTagIgnore => 'ИГНОР.';

  @override
  String get onDemandNewRule => 'Новое правило';

  @override
  String get onDemandActionIgnore => 'Игнорировать';

  @override
  String get onDemandActionConnectSubtitle => 'поднять туннель';

  @override
  String get onDemandActionDisconnectSubtitle => 'разорвать туннель';

  @override
  String get onDemandActionIgnoreSubtitle => 'оставить туннель как есть';

  @override
  String get onDemandAny => 'Любая';

  @override
  String get onDemandNameOptional => 'Название (необязательно)';

  @override
  String get onDemandNameHint => 'Офис';

  @override
  String get onDemandNetworkHeader => 'СЕТЬ';

  @override
  String get onDemandNetworkHelpAny =>
      'Правило проверяется в любой сети — Wi-Fi, мобильной или проводной.';

  @override
  String get onDemandNetworkHelpWifi =>
      'Когда устройство подключается к сети Wi-Fi, система проверяет условия ниже и применяет правило.';

  @override
  String get onDemandNetworkHelpCellular =>
      'Когда устройство использует мобильный интернет, система проверяет условия ниже и применяет правило.';

  @override
  String get onDemandNetworkHelpEthernet =>
      'Когда устройство подключено к проводной сети, система проверяет условия ниже и применяет правило.';

  @override
  String get onDemandConditionsHeader => 'УСЛОВИЯ';

  @override
  String get onDemandWifiNetworks => 'Сети Wi-Fi';

  @override
  String get onDemandWifiNetwork => 'Сеть Wi-Fi';

  @override
  String get onDemandNetworksUnit => 'СЕТИ';

  @override
  String get onDemandWifiNetworksHelp =>
      'Имя сети должно совпадать точно. Оставьте пустым для любой сети Wi-Fi.';

  @override
  String get onDemandDnsDomains => 'Поисковые домены DNS';

  @override
  String get onDemandDnsDomain => 'Поисковый домен DNS';

  @override
  String get onDemandDomainsUnit => 'ДОМЕНЫ';

  @override
  String get onDemandDnsDomainsHelp =>
      'Совпадает, если поисковый домен сети заканчивается на одну из записей.';

  @override
  String get onDemandDnsServers => 'Серверы DNS';

  @override
  String get onDemandDnsServer => 'Сервер DNS';

  @override
  String get onDemandServersUnit => 'СЕРВЕРЫ';

  @override
  String get onDemandDnsServersHelp =>
      'Сравнивается с серверами DNS сети; допускается один символ «*».';

  @override
  String get onDemandUrlProbeHeader => 'ПРОВЕРКА URL';

  @override
  String get onDemandUrlOptional => 'URL (необязательно)';

  @override
  String get onDemandUrlProbeHelp =>
      'Правило совпадает, только если этот URL отвечает 200 без перенаправлений.';

  @override
  String get onDemandNoEntries => 'НЕТ ЗАПИСЕЙ';

  @override
  String onDemandEntriesHeader(int count, String unit) {
    return '$count $unit · ДОСТАТОЧНО ОДНОГО СОВПАДЕНИЯ';
  }

  @override
  String get onDemandConditionIgnored =>
      'Условие не учитывается, правило совпадает с любой сетью выбранного типа.';

  @override
  String get onDemandInterfaceAny => 'Любая сеть';

  @override
  String get onDemandInterfaceWifi => 'Wi-Fi';

  @override
  String get onDemandInterfaceCellular => 'Мобильная';

  @override
  String get onDemandInterfaceEthernet => 'Ethernet';

  @override
  String onDemandSummarySsid(String values) {
    return 'SSID $values';
  }

  @override
  String onDemandSummaryDomain(String values) {
    return 'домен $values';
  }

  @override
  String onDemandSummaryDns(String values) {
    return 'DNS $values';
  }

  @override
  String get onDemandSummaryProbe => 'проверка URL';

  @override
  String get onDemandStatusPaused => 'Приостановлено';

  @override
  String get onDemandStatusAwaitingFirstConnect =>
      'Вкл. · после первого подключения';

  @override
  String onDemandStatusOnRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вкл. · $count правила',
      many: 'Вкл. · $count правил',
      few: 'Вкл. · $count правила',
      one: 'Вкл. · 1 правило',
    );
    return '$_temp0';
  }

  @override
  String get onDemandDefaultRuleName => 'Везде';

  @override
  String get statusNoConfiguration => 'Нет конфигурации';

  @override
  String get menuBarSwitching => 'Переключение…';

  @override
  String profilesCouldntGetServer(String label) {
    return 'Не удалось получить сервер для $label';
  }

  @override
  String get profilesPreviousServerStillInUse =>
      'Прежний по-прежнему используется.';

  @override
  String get profilesCouldntSwitch => 'Не удалось переключиться';

  @override
  String get profilesCouldntSwitchDetail =>
      'Туннель остался на прежней конфигурации. Попробуйте ещё раз или переподключитесь.';

  @override
  String get profilesNoConfigurationDetail =>
      'Добавьте ссылку, подписку или войдите на свой сервер.';

  @override
  String get profilesNoServers => 'В этой конфигурации нет серверов';

  @override
  String get profilesNoServersDetail =>
      'Обновите её или добавьте другую конфигурацию.';

  @override
  String get profilesTunnelStopped => 'Туннель остановился';

  @override
  String get connectionCheckTimedOut => 'Сервер не ответил вовремя.';

  @override
  String get connectionCheckClosed => 'Сервер закрыл соединение.';

  @override
  String get connectionCheckRefused => 'Сервер отклонил соединение.';

  @override
  String get connectionCheckNoServer =>
      'Проверять нечего — в туннеле работает что-то другое.';

  @override
  String get connectionCheckTunnelNotRunning => 'Туннель не работает.';

  @override
  String get connectionCheckNothingCameBack => 'Ответа не пришло.';

  @override
  String get connectionCheckEngineDidNotAnswer => 'Движок не ответил.';

  @override
  String get errorDeviceLimitTitle => 'Достигнут лимит устройств';

  @override
  String get errorDeviceLimitDetail =>
      'Лимит устройств подписки исчерпан, поэтому вместо серверов она прислала заглушку. Освободите слот в подписке и обновите конфигурацию.';

  @override
  String get errorUnreadableSubscriptionTitle =>
      'Не удалось прочитать подписку';

  @override
  String get errorUnreadableSubscriptionDetail =>
      'Подписка прислала формат, который это приложение не распознаёт. Оно читает списки ссылок в base64, Clash / mihomo, Xray JSON и sing-box. Ничего не добавлено.';

  @override
  String get errorEmptySubscriptionTitle => 'В этой подписке нет серверов';

  @override
  String errorEmptySubscriptionDetail(String what) {
    return 'Подписка прислала $what, где не указано ни одного сервера. Обычно это значит, что у аккаунта закончились дни или исчерпан лимит устройств — уточните у них.';
  }

  @override
  String errorNoRunnableServersTitle(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Ни один из $total серверов здесь не запустится',
      many: 'Ни один из $total серверов здесь не запустится',
      few: 'Ни один из $total серверов здесь не запустится',
      one: 'Единственный сервер здесь не запустится',
    );
    return '$_temp0';
  }

  @override
  String errorNoRunnableServersDetail(String kinds) {
    return 'Они используют $kinds, а это приложение пока такого не умеет. Ничего не добавлено.';
  }

  @override
  String get errorProviderMessageTitle => 'Подписка прислала сообщение';

  @override
  String errorProviderMessageDetail(String lines) {
    return '$lines\n\nЭто не серверы: каждая запись ведёт в никуда, поэтому ничего не добавлено.';
  }

  @override
  String get errorSubjectDefault => 'сервер';

  @override
  String get errorServerDidNotAnswerTitle => 'Сервер не ответил';

  @override
  String errorCouldNotReachDetail(String what) {
    return 'Не удалось связаться с $what. Проверьте сеть или выберите другой сервер.';
  }

  @override
  String get errorSecureConnectionTitle =>
      'Не удалось установить защищённое соединение';

  @override
  String errorCertificateRejectedDetail(String what) {
    return 'Сертификат $what отклонён. Если адрес верный, возможно, сервер настроен неправильно.';
  }

  @override
  String errorConnectionClosedDetail(String what) {
    return 'Соединение с $what было закрыто.';
  }

  @override
  String get errorWrongCredentialsTitle =>
      'Неверное имя пользователя или пароль';

  @override
  String get errorWrongCredentialsDetail => 'Проверьте оба и попробуйте снова.';

  @override
  String get errorSessionExpiredTitle => 'Сессия истекла';

  @override
  String errorSessionExpiredDetail(String what) {
    return 'Войдите на $what ещё раз.';
  }

  @override
  String get errorAccessBlockedTitle => 'Доступ заблокирован';

  @override
  String get errorAccessBlockedDetail => 'Сервер отклонил этот аккаунт.';

  @override
  String get errorNothingAtAddressTitle => 'По этому адресу ничего нет';

  @override
  String errorNothingAtAddressDetail(String what) {
    return 'Проверьте ссылку — у $what нет конфигурации для этого аккаунта.';
  }

  @override
  String get errorServerErrorTitle => 'Сервер вернул ошибку';

  @override
  String get errorServerErrorDetail =>
      'С вашей стороны исправлять нечего — попробуйте через несколько минут.';

  @override
  String get errorServerRefusedTitle => 'Сервер отклонил запрос';

  @override
  String get errorNotALinkTitle => 'Это не похоже на знакомую ссылку';

  @override
  String get errorNotALinkDetail =>
      'Ожидается vless://, vmess://, trojan://, ss:// или URL подписки.';

  @override
  String get errorTunnelServiceNotRunningTitle => 'Служба туннеля не запущена';

  @override
  String get errorTunnelServiceNotRunningDetail =>
      'Anoya устанавливает её как службу Windows «AnoyaTunnel». Переустановите приложение или запустите службу в «Службах», затем подключитесь снова.';

  @override
  String get errorTunnelServiceNotRunningDetailLinux =>
      'Anoya устанавливает её как службу systemd «anoya-tunnel». Переустановите пакет или выполните «sudo systemctl start anoya-tunnel», затем подключитесь снова.';

  @override
  String get errorTunnelServiceStoppedTitle => 'Служба туннеля остановилась';

  @override
  String get errorTunnelServiceStoppedDetail =>
      'Она сама перезапустится через несколько секунд — подключитесь снова. Если это повторяется, причина в журнале туннеля: Настройки → Журналы.';

  @override
  String get errorSystemRefusedTunnelTitle =>
      'Система не разрешила запустить туннель';

  @override
  String get errorSystemRefusedTunnelDetail =>
      'Разрешите профиль VPN в системных настройках, затем подключитесь снова.';

  @override
  String get errorSignInNotFinishedTitle => 'Вход не завершён';

  @override
  String get errorSignInNotFinishedDetail =>
      'Окно браузера было закрыто, или провайдер отказал.';

  @override
  String get errorSomethingWentWrongTitle => 'Что-то пошло не так';

  @override
  String get errorSomethingWentWrongDetail =>
      'Подробности — в Настройки → Журналы.';

  @override
  String get errorDeviceNotAcceptedTitle =>
      'Подписка не приняла это устройство';

  @override
  String get errorDeviceNotAcceptedDetail =>
      'Ей нужен id устройства, и приложение его отправило. Обратитесь в поддержку подписки.';

  @override
  String errorApiTimeout(String baseUrl) {
    return 'Нет ответа от $baseUrl — проверьте адрес и сеть.';
  }

  @override
  String errorApiNetwork(String baseUrl) {
    return 'Не удалось связаться с $baseUrl — проверьте адрес и порт и убедитесь, что сервер работает.';
  }

  @override
  String errorApiTls(String baseUrl) {
    return 'Ошибка TLS при обращении к $baseUrl. Если сервер работает по обычному HTTP, введите адрес с «http://».';
  }

  @override
  String errorApiRequest(String baseUrl) {
    return 'Запрос к $baseUrl не удалось выполнить — проверьте адрес и попробуйте снова.';
  }

  @override
  String get accountExpiredDetail =>
      'Продлите её в своём аккаунте, затем подключитесь снова.';

  @override
  String get accountLimitedTitle => 'Достигнут лимит трафика';

  @override
  String get accountLimitedDetail => 'Тариф исчерпан до следующего продления.';

  @override
  String get accountDeactivatedTitle => 'Доступ отключён';

  @override
  String get accountDeactivatedDetail => 'Администратор отключил этот аккаунт.';

  @override
  String get accountOnHoldTitle => 'Подписка ещё не началась';

  @override
  String get accountOnHoldDetail =>
      'Она начинается с первого подключения — попробуйте ещё раз чуть позже.';

  @override
  String accountOtherStateTitle(String state) {
    return 'Статус аккаунта: $state';
  }

  @override
  String get accountOtherStateDetail => 'В этом состоянии подключаться нельзя.';

  @override
  String get amneziaErrorEmptyAnswerTitle => 'Шлюз ничего не прислал';

  @override
  String get amneziaErrorEmptyAnswerDetail =>
      'Он ответил без конфигурации. Попробуйте снова; если повторится, этим должна заняться поддержка подписки.';

  @override
  String get amneziaErrorCancelledTitle => 'Слишком долго';

  @override
  String get amneziaErrorCancelledDetail =>
      'Шлюз не ответил вовремя. Проверьте соединение и попробуйте снова.';

  @override
  String get amneziaErrorNetworkTitle => 'Не удалось связаться со шлюзом';

  @override
  String get amneziaErrorNetworkDetail =>
      'Шлюз не ответил. Обычно дело в сети, а не в подписке — попробуйте ещё раз чуть позже.';

  @override
  String get amneziaErrorTimeoutTitle => 'Шлюз не ответил вовремя';

  @override
  String get amneziaErrorTimeoutDetail =>
      'Ответа не было в отведённое время. Проверьте соединение и попробуйте снова.';

  @override
  String get amneziaErrorSslTitle => 'Соединение не заслуживает доверия';

  @override
  String get amneziaErrorSslDetail =>
      'Что-то вмешалось в защищённое соединение со шлюзом.';

  @override
  String get amneziaErrorConfigTitle =>
      'Эта сборка не может обращаться к шлюзу';

  @override
  String get amneziaErrorConfigDetail =>
      'Она собрана без учётных данных шлюза, поэтому подписки такого типа в ней недоступны.';

  @override
  String get amneziaErrorDecryptTitle => 'Не удалось прочитать ответ';

  @override
  String get amneziaErrorDecryptDetail =>
      'Ответ не похож на то, что должен присылать шлюз — часто так бывает в сети, которая перехватывает трафик.';

  @override
  String get amneziaErrorInvalidArgumentTitle =>
      'Запрос к шлюзу составлен неверно';

  @override
  String get amneziaErrorInvalidArgumentDetail =>
      'Это дефект приложения, а не подписки. Помогает перезапуск; если повторится, поддержке понадобится журнал из Настройки → Журналы.';

  @override
  String get amneziaErrorRefusedTitle => 'Шлюз отклонил запрос';

  @override
  String amneziaErrorRefusedCodeDetail(int code) {
    return 'Шлюз ответил кодом $code.';
  }

  @override
  String amneziaErrorRefusedHttpDetail(int status) {
    return 'Шлюз ответил HTTP $status.';
  }

  @override
  String get amneziaErrorTooManyRequestsTitle => 'Слишком много запросов';

  @override
  String get amneziaErrorTooManyRequestsDetail =>
      'Шлюз ограничивает эту подписку. Подождите несколько минут, прежде чем пробовать снова.';

  @override
  String get amneziaErrorTrialUsedTitle => 'Пробный период уже использован';

  @override
  String get amneziaErrorTrialUsedDetail =>
      'С этого адреса пробный период уже активировали.';

  @override
  String get amneziaErrorDeviceLimitDetail =>
      'Эта подписка уже установлена на максимально допустимом числе устройств. Удалите одно из них в подписке и попробуйте снова.';

  @override
  String get amneziaErrorNotFoundTitle => 'Подписка не найдена';

  @override
  String get amneziaErrorNotFoundDetail =>
      'Шлюз не узнаёт этот ключ. Проверьте, что он вставлен целиком.';

  @override
  String get amneziaErrorNewerClientTitle =>
      'Шлюзу нужна более новая версия клиента';

  @override
  String get amneziaErrorNewerClientDetail =>
      'Шлюз отклонил эту версию приложения. После обновления приложения всё заработает снова.';

  @override
  String get amneziaErrorCaptchaPass =>
      'Пройдите её в приложении, из которого взята подписка, затем обновите здесь.';

  @override
  String get amneziaErrorCaptchaExpiredTitle => 'CAPTCHA устарела';

  @override
  String get amneziaErrorCaptchaRejectedTitle => 'CAPTCHA не принята';

  @override
  String get amneziaErrorCaptchaAskedTitle => 'Шлюз запросил CAPTCHA';

  @override
  String amneziaErrorCaptchaAskedDetail(String pass) {
    return 'Это приложение не может её показать. $pass';
  }

  @override
  String get amneziaErrorNotActiveTitle => 'Подписка не активна';

  @override
  String get amneziaErrorNotActiveDetail =>
      'У шлюза нет активной подписки для этого ключа.';

  @override
  String get amneziaErrorLostKeyTitle => 'У этой подписки потерян ключ';

  @override
  String get amneziaErrorLostKeyDetail =>
      'Удалите конфигурацию и добавьте её заново.';

  @override
  String get amneziaErrorFreeTierUnsupported =>
      'Это бесплатная подписка, и её шлюз требует пройти CAPTCHA, прежде чем выдать конфигурацию, — а это приложение не может её показать. Используйте приложение, из которого взята подписка, или добавьте сюда платный ключ.';

  @override
  String get importNotAKeyTitle => 'Это не ключ подписки';

  @override
  String get importNotAKeyDetail => 'Ожидается ключ vpn:// из вашей подписки.';

  @override
  String importKeyUnsupportedTitle(String name) {
    return '$name здесь не поддерживается';
  }

  @override
  String importImportedName(int count) {
    return 'Импортировано ($count)';
  }

  @override
  String get importFormatLinks => 'список ссылок';

  @override
  String get importFormatClash => 'подписку Clash / mihomo';

  @override
  String get importFormatXray => 'подписку Xray JSON';

  @override
  String get importFormatSingbox => 'подписку sing-box';

  @override
  String get importFormatUnknown => 'что-то нераспознанное';

  @override
  String importDetectedAmneziaKey(String name) {
    return '$name · ключ подписки';
  }

  @override
  String importDetectedServer(String type, String label) {
    return 'Сервер $type · $label';
  }

  @override
  String importDetectedSubscriptionUrl(String host) {
    return 'URL подписки · $host';
  }

  @override
  String importDetectedSingleServer(String label) {
    return 'Сервер · $label';
  }

  @override
  String importDetectedSubscriptionText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сервера',
      many: '$count серверов',
      few: '$count сервера',
      one: '1 сервер',
    );
    return 'Подписка · $_temp0';
  }

  @override
  String get importUnusableNotSubscriptionKey => 'Это не ключ подписки';

  @override
  String importUnusableNotSupported(String what) {
    return '$what не поддерживается';
  }

  @override
  String importUnusableTransportNotSupported(String scheme, String transport) {
    return '$scheme поверх $transport не поддерживается';
  }

  @override
  String importUnusableLinkUnreadable(String scheme) {
    return 'не удалось прочитать ссылку $scheme://';
  }

  @override
  String get importUnusableNotALink => 'Это не ссылка и не подписка';

  @override
  String get catalogGroupStreaming => 'СТРИМИНГ';

  @override
  String get catalogGroupMessengers => 'МЕССЕНДЖЕРЫ';

  @override
  String get catalogGroupSocial => 'СОЦСЕТИ';

  @override
  String get catalogGroupOther => 'ДРУГОЕ';

  @override
  String proxyGroupUrlTest(int count) {
    return 'Наименьшая задержка из $count';
  }

  @override
  String proxyGroupFallback(int count) {
    return 'Первый отвечающий из $count · в их порядке';
  }

  @override
  String proxyGroupLoadBalance(int count) {
    return 'Распределение между $count';
  }

  @override
  String proxyGroupRelay(int count) {
    return 'Цепочка из $count';
  }
}
