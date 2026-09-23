// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'VPN';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDone => '完成';

  @override
  String get commonOk => '好';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRemove => '移除';

  @override
  String get commonAdd => '添加';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRetry => '重试';

  @override
  String get commonCopy => '复制';

  @override
  String get commonCopied => '已复制';

  @override
  String get commonSettings => '设置';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonDismiss => '忽略';

  @override
  String get commonOn => '开';

  @override
  String get commonOff => '关';

  @override
  String get commonConnect => '连接';

  @override
  String get commonDisconnect => '断开';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonOpen => '打开';

  @override
  String get commonBack => '返回';

  @override
  String get commonContinue => '继续';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRename => '重命名';

  @override
  String get commonName => '名称';

  @override
  String get commonAll => '全部';

  @override
  String get commonFavorites => '收藏';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get commonClear => '清除';

  @override
  String get commonJustNow => '刚刚';

  @override
  String get settingsSectionConfigurations => '配置';

  @override
  String get settingsSectionConnection => '连接';

  @override
  String get settingsSectionRouting => '路由';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionDiagnostics => '诊断';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsConfigurations => '配置';

  @override
  String settingsConfigurationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个配置',
      one: '1 个配置',
    );
    return '$_temp0';
  }

  @override
  String get uiNounConfiguration => '配置';

  @override
  String get settingsAutoConnect => '自动连接';

  @override
  String get settingsAutoConnectSubtitle => 'Windows 启动时连接';

  @override
  String get onDemandTitle => '按需连接';

  @override
  String get settingsDisconnectOnSleep => '睡眠时断开';

  @override
  String get settingsDisconnectOnSleepSubtitle => '设备进入睡眠时关闭隧道';

  @override
  String get settingsAlwaysOnSubtitle => '系统级开关，在 Android 设置中管理';

  @override
  String get settingsAdvanced => '高级';

  @override
  String get settingsConnectionCheckOn => '连接检测 · 开';

  @override
  String get settingsConnectionCheckOff => '连接检测 · 关';

  @override
  String get settingsLanDirect => '局域网直连';

  @override
  String get settingsLanDirectSubtitle => '局域网流量不经过 VPN';

  @override
  String get ruleSetsTitle => '规则集';

  @override
  String settingsRuleSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个规则集',
      one: '1 个规则集',
    );
    return '$_temp0';
  }

  @override
  String get settingsDefaultDns => '默认 DNS';

  @override
  String settingsDefaultDnsSubtitle(String name) {
    return '$name · 配置未指定 DNS 时使用';
  }

  @override
  String get settingsDnsCustom => '自定义…';

  @override
  String get settingsDnsCustomSubtitle => '引擎支持的任意地址';

  @override
  String get settingsDnsResolverLabel => '解析服务器';

  @override
  String get settingsDnsUseCloudflare => '使用 Cloudflare';

  @override
  String settingsGeoDownloaded(String size) {
    return '已下载 · $size';
  }

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeSystemSubtitle => '跟随设备设置';

  @override
  String get aboutTitle => '关于';

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get aboutEngine => '引擎';

  @override
  String get aboutVersionCopied => '版本号已复制';

  @override
  String get aboutTermsOfService => '服务条款';

  @override
  String get aboutPrivacyPolicy => '隐私政策';

  @override
  String get aboutNotPublishedYet => '尚未发布';

  @override
  String get uiCouldNotOpenPage => '无法打开该页面。';

  @override
  String get advancedSectionConnectionCheck => '连接检测';

  @override
  String get advancedSectionLastCheck => '上次检测';

  @override
  String get advancedCheckAfterConnecting => '连接后检测';

  @override
  String get advancedCheckAfterConnectingSubtitle => '通过服务器请求一个页面并计时';

  @override
  String get advancedTestUrl => '测试 URL';

  @override
  String get advancedUrlLabel => 'URL';

  @override
  String get advancedUseDefault => '使用默认值';

  @override
  String get advancedInvalidUrl => '请输入以 http:// 或 https:// 开头的地址。';

  @override
  String get advancedGiveUpAfter => '超时时间';

  @override
  String advancedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒',
      one: '1 秒',
    );
    return '$_temp0';
  }

  @override
  String get advancedTestNow => '立即测试';

  @override
  String get advancedNeedsTunnelNote => '请求经由运行中的引擎发出，因此需要先建立隧道才能测试。';

  @override
  String get advancedCheckScopeNote =>
      '请求直接经由服务器发出，不受路由规则影响。它只能证明服务器能够转发流量，并不代表你的流量正在经过它。';

  @override
  String get advancedNoAnswer => '无响应';

  @override
  String advancedNoAnswerDetail(String failure) {
    return '$failure 隧道已建立，问题出在服务器或其后方的网络。';
  }

  @override
  String get advancedTrafficGettingThrough => '流量正常通行';

  @override
  String advancedAnsweredIn(int ms) {
    return '$ms 毫秒内响应';
  }

  @override
  String advancedResultVia(String ago, String via) {
    return '$ago · 经由 $via';
  }

  @override
  String commonMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String advancedHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String get alwaysOnTitle => '始终开启的 VPN';

  @override
  String get alwaysOnStartedBySystem => '由系统启动';

  @override
  String get alwaysOnStartedBySystemSubtitle => '开机时启动，隧道断开后自动重连';

  @override
  String get alwaysOnBlockWithoutVpn => '阻止未经 VPN 的连接';

  @override
  String get alwaysOnBlockWithoutVpnSubtitle => '系统自带的终止开关，位于同一页面';

  @override
  String get alwaysOnNote =>
      '此开关由 Android 管理，位于系统设置：网络和互联网 → VPN → 本应用旁的齿轮图标。系统会启动上次使用的配置。';

  @override
  String get alwaysOnOpenSystemSettings => '打开系统 VPN 设置';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get dnsSectionInEffect => '正在使用';

  @override
  String get dnsSectionDropped => '已弃用';

  @override
  String get dnsParallelNote => '同时查询，采用最先返回的结果。';

  @override
  String get dnsFallbackNote => '此配置未指定解析服务器，因此使用应用默认值。可在“设置 › 默认 DNS”中更改。';

  @override
  String get dnsProviderNote => '由此配置的提供方设定，并随配置一同更新。';

  @override
  String get dnsProxyResolvedDirectlyNote =>
      '所连接服务器的地址始终直接解析。这是必要的，否则任何流量都无法到达隧道。';

  @override
  String dnsResolverSubtitle(String protocol, String origin) {
    return '$protocol · $origin';
  }

  @override
  String get dnsPinIgnoredTooltip =>
      '此配置要求使用本应用不会创建的出站方式，因此该请求已被弃用，解析服务器将直接访问。';

  @override
  String get dnsOriginAppDefault => '应用默认';

  @override
  String get dnsOriginSubscription => '来自订阅';

  @override
  String get dnsOriginOrganisation => '来自组织';

  @override
  String get dnsOriginConfiguration => '来自此配置';

  @override
  String get dnsRoutingDirect => '直连';

  @override
  String get dnsRoutingFollowsRules => '遵循规则';

  @override
  String get dnsRoutingThroughTunnel => '经由隧道';

  @override
  String get dnsProtocolDoh => 'DNS over HTTPS';

  @override
  String get dnsProtocolDot => 'DNS over TLS';

  @override
  String get dnsProtocolDoq => 'DNS over QUIC';

  @override
  String get dnsProtocolPlain => '明文，未加密';

  @override
  String get dnsDropMalformed => '不是有效的解析服务器地址。订阅中的内容不会未经检查就写入引擎配置。';

  @override
  String get dnsDropUnknownScheme => '引擎不支持此协议。若保留，整个配置都会失效，而不只是这一行。';

  @override
  String get dnsDropCannotCarry =>
      '明文 DNS 无法经由此服务器传输，而在隧道外发送会把你访问的每个网站暴露给所在网络。';

  @override
  String dnsDropTooMany(int max) {
    return '超出了引擎最多接受的 $max 个。引擎会同时查询所有服务器，列表过长只会更耗时，并不会得到更好的结果。';
  }

  @override
  String get dnsPresetQuad9Note => '过滤已知恶意域名';

  @override
  String get dnsPresetAdGuardNote => '过滤广告和跟踪器';

  @override
  String get dnsErrorNotResolverAddress => '不是有效的解析服务器地址。';

  @override
  String get dnsErrorAddressedByName => '使用了域名，需要先解析自身才能解析其他内容。请改用其 IP 地址。';

  @override
  String get geoTitle => 'GeoIP 与 GeoSite';

  @override
  String get geoSectionDatabases => '数据库';

  @override
  String get geoSectionUpdates => '更新';

  @override
  String get geoGeoipSource => 'GeoIP 来源';

  @override
  String get geoGeositeSource => 'GeoSite 来源';

  @override
  String get geoDownloadUrlLabel => '下载 URL';

  @override
  String get geoResetToDefault => '恢复默认';

  @override
  String get geoNotDownloaded => '未下载';

  @override
  String get geoNever => '从未';

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
      one: '1 小时前',
    );
    return '$_temp0';
  }

  @override
  String get geoLastUpdated => '上次更新';

  @override
  String get geoAutoUpdate => '自动更新';

  @override
  String get geoAutoUpdateSubtitle => '已下载时每周更新';

  @override
  String get geoUpdateNow => '立即更新';

  @override
  String get geoDownload => '下载（约 25 MB）';

  @override
  String get geoDatabaseHostSubject => '数据库服务器';

  @override
  String get geositeCategoryLabel => '类别';

  @override
  String geositeDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个域名',
      one: '1 个域名',
    );
    return '$_temp0';
  }

  @override
  String get geositeNoCategories => '没有类别，请先下载地理数据库。';

  @override
  String uiNothingMatches(String query) {
    return '没有与“$query”匹配的结果。';
  }

  @override
  String get geositeSectionPopular => '常用';

  @override
  String geositeSectionAll(int count) {
    return '全部 · $count';
  }

  @override
  String geositeSectionAllMatch(int count, int total) {
    return '全部 · $total 项中匹配 $count 项';
  }

  @override
  String get logsTitle => '日志';

  @override
  String get logsSectionCollection => '收集';

  @override
  String get logsSectionTunnel => '隧道';

  @override
  String get logsSectionApp => '应用';

  @override
  String get logsCollect => '收集日志';

  @override
  String get logsCollectSubtitle => '关闭后，应用、隧道和核心都停止写入。已有文件仍可查看。';

  @override
  String get logsTunnel => '隧道';

  @override
  String get logsTunnelSubtitle => 'Network Extension 事件';

  @override
  String get logsCore => '核心（mihomo）';

  @override
  String get logsCoreSubtitle => '引擎日志：拨号、DNS、路由';

  @override
  String get logsApplication => '应用';

  @override
  String get logsApplicationSubtitle => '客户端事件';

  @override
  String get logsSaveAllZip => '保存全部日志（.zip）';

  @override
  String get logsSaveAll => '保存全部日志';

  @override
  String get logsSaveToFile => '保存到文件…';

  @override
  String get logsSaveToFileSubtitle => '选择本设备上的文件夹';

  @override
  String get logsShare => '分享…';

  @override
  String get logsShareSubtitle => '将压缩包发送到其他位置';

  @override
  String get logsSaveDialogTitle => '保存日志';

  @override
  String logsSavedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get logsClearAll => '清除全部日志';

  @override
  String get logsClearAllQuestion => '清除全部日志？';

  @override
  String get logsClearAllContent => '应用、隧道和核心日志将从本设备删除。隧道和核心日志仅在 VPN 已连接时才能清除。';

  @override
  String get logsCleared => '日志已清除。';

  @override
  String get logsAppLogClearedOnly => '应用日志已清除。清除隧道和核心日志需要先连接 VPN。';

  @override
  String get logsNoLog => '没有日志。';

  @override
  String get logsNoLogYet => '暂无日志。';

  @override
  String get logsEmpty => '空';

  @override
  String get logsUnavailable =>
      '日志仅在隧道运行时可用。\n（隧道进程在自己一侧保存日志，并通过 IPC 流式传送给应用。）';

  @override
  String get commonTryAgain => '重试';

  @override
  String configKindSelfhosted(String servers) {
    return '自建 · $servers';
  }

  @override
  String configKindSubscription(String servers, String groups) {
    return '订阅 · $servers$groups';
  }

  @override
  String get configKindSubscriptionPlain => '订阅';

  @override
  String get configKindSingleServer => '单个服务器';

  @override
  String commonServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台服务器',
      one: '1 台服务器',
    );
    return '$_temp0';
  }

  @override
  String configServersOfOffered(int ours, int offered) {
    String _temp0 = intl.Intl.pluralLogic(
      offered,
      locale: localeName,
      other: '$offered 台服务器中的 $ours 台',
      one: '1 台服务器中的 $ours 台',
    );
    return '$_temp0';
  }

  @override
  String configGroupsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count 个分组',
      one: ' · 1 个分组',
    );
    return '$_temp0';
  }

  @override
  String get configSource => '来源';

  @override
  String get configSourceViaFallback => '上次刷新使用了订阅的备用地址';

  @override
  String get configCouldNotOpenLink => '无法打开该链接。';

  @override
  String get configLinkCopied => '链接已复制';

  @override
  String configUnsupportedTitle(int skipped, int offered) {
    return '$offered 台服务器中有 $skipped 台不受支持';
  }

  @override
  String configUnsupportedDetail(String kinds, int available) {
    return '它们使用 $kinds，本应用暂不支持。其余 $available 台可以使用。';
  }

  @override
  String get configSetActive => '设为当前';

  @override
  String get configRemoveConfiguration => '移除配置';

  @override
  String configRemoveTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get configRemoveDetail => '此配置将从本设备移除。';

  @override
  String get configSectionSubscription => '订阅';

  @override
  String get configRanUntil => '有效期至';

  @override
  String get configRunsUntil => '有效期至';

  @override
  String get configDevices => '设备';

  @override
  String configDevicesUsed(int active, int max) {
    return '已用 $active，上限 $max';
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
      other: '剩 $count 天',
      one: '剩 1 天',
    );
    return '$date · $_temp0';
  }

  @override
  String get accountExpiredTitle => '订阅已过期';

  @override
  String get configSubscriptionExpiredDetail => '请续订后再刷新此配置。';

  @override
  String get configSectionThisDevice => '本设备';

  @override
  String get configDeviceIdentifiedSubtitle => '订阅按设备计数，此 ID 用于识别本设备';

  @override
  String get configDeviceId => '设备 ID';

  @override
  String get configDeviceHintAmnezia =>
      '订阅按此 ID 统计设备数。它只生成一次并长期保留，重新连接不会占用新名额，但重新安装会生成新的 ID。';

  @override
  String get configDeviceHintPanel =>
      '订阅按本应用生成并保留的 ID 统计设备数。重新安装会生成新的 ID，并占用另一个名额。';

  @override
  String configCopiedTitle(String title) {
    return '$title已复制';
  }

  @override
  String configDnsSummary(String host, String routing) {
    return '$host · $routing';
  }

  @override
  String configDnsMore(int count) {
    return ' · 另有 $count 个';
  }

  @override
  String configDnsDropped(int count) {
    return '$count 个已弃用';
  }

  @override
  String get configDnsByApp => 'DNS 由应用提供';

  @override
  String configDnsOrigin(String origin) {
    return 'DNS $origin';
  }

  @override
  String configDnsRefused(int count) {
    return 'DNS：$count 个已拒绝';
  }

  @override
  String get configRouting => '路由';

  @override
  String get configRuleSet => '规则集';

  @override
  String get configRuleSetDefault => '默认';

  @override
  String get configRuleLists => '规则列表';

  @override
  String get ruleSetModeSplit => '分流';

  @override
  String get ruleSetModeFull => '全局隧道';

  @override
  String ruleSetSummary(String mode, String rules) {
    return '$mode · $rules';
  }

  @override
  String get ruleSetNoRules => '无规则';

  @override
  String get configNoExceptions => '无例外';

  @override
  String configRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条规则',
      one: '1 条规则',
    );
    return '$_temp0';
  }

  @override
  String configSkippedNotSupported(int count) {
    return '$count 条不受支持';
  }

  @override
  String configListsUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个列表不可用',
      one: '1 个列表不可用',
    );
    return '$_temp0';
  }

  @override
  String configRulesNeedLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条规则需要其列表',
      one: '1 条规则需要其列表',
    );
    return '$_temp0';
  }

  @override
  String configDownloadingLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在下载 $count 个列表…',
      one: '正在下载 1 个列表…',
    );
    return '$_temp0';
  }

  @override
  String configRuleListsOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条规则需要它们',
      one: '1 条规则需要它们',
    );
    return '关 · $_temp0';
  }

  @override
  String get configChecking => '正在检查…';

  @override
  String get configNoneDownloadedYet => '尚未下载';

  @override
  String configListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个列表',
      one: '1 个列表',
    );
    return '$_temp0';
  }

  @override
  String configListsDownloadedOf(int have, int total) {
    return '已下载 $have/$total';
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
      other: '有 $count 个列表无法下载',
      one: '有 1 个列表无法下载',
    );
    return '$_temp0';
  }

  @override
  String configListsFailedDetail(int count, String names, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names（来自 $hosts），使用它们的规则未生效。',
      one: '$names（来自 $hosts），使用它的规则未生效。',
    );
    return '$_temp0';
  }

  @override
  String configReplacedBy(String name) {
    return '已被$name取代';
  }

  @override
  String get configRoutingOffSummary => '关 · 全部流量经由 VPN';

  @override
  String get configManagedByOrganization => '由你的组织管理';

  @override
  String configManagedSummary(String mode, int count) {
    return '$mode · $count 条规则，在服务器端设定';
  }

  @override
  String configSetByOrganization(String mode) {
    return '$mode · 由你的组织设定';
  }

  @override
  String get configSectionOrganizationRouting => '组织路由';

  @override
  String get configSectionSubscriptionRouting => '订阅路由';

  @override
  String get configSectionDeviceRouting => '设备路由';

  @override
  String get configOrganizationRoutingNote =>
      '此策略由你的组织设定并强制执行。你可以查看内容，但更改需在组织一侧进行。';

  @override
  String get configSubscriptionRoutes => '订阅的路由';

  @override
  String get configSubscriptionRoutingNote =>
      '关闭开关即可改用你自己的规则集。无论开关状态如何，订阅都无法强制执行此策略。';

  @override
  String get configDeviceRoutingNote =>
      '规则集由所有配置共享；开关则按配置单独设置，因此工作订阅和个人订阅可以用不同方式使用同一规则集。';

  @override
  String get configSectionDetails => '详情';

  @override
  String get configGetSupport => '获取支持';

  @override
  String get configNoPlanDetails => '订阅未报告套餐详情。';

  @override
  String configUsedNoLimit(String used) {
    return '已用 $used · 无限制';
  }

  @override
  String configTrafficOf(String used, String total) {
    return '流量：$used / $total';
  }

  @override
  String get configNoExpiryDate => '未提供到期日期';

  @override
  String configExpiredOn(String date) {
    return '已于 $date 过期';
  }

  @override
  String configActiveUntil(String date) {
    return '有效期至 $date';
  }

  @override
  String configPlanLine(String when) {
    return '$when · 订阅方报告的数据，本应用未作核实';
  }

  @override
  String get configAccount => '账户';

  @override
  String configStatus(String status) {
    return '状态：$status';
  }

  @override
  String configStatusOnHold(String status) {
    return '状态：$status · 首次使用时开始';
  }

  @override
  String configStatusExpires(String status, String date) {
    return '状态：$status · $date 到期';
  }

  @override
  String get configLastRefreshed => '上次刷新';

  @override
  String get configRefreshEvery => '刷新间隔';

  @override
  String get configHours => '小时';

  @override
  String get configRefreshAsSubscriptionAsks => '按订阅要求';

  @override
  String get configRefreshEnterWholeHours => '请输入整数小时。';

  @override
  String configRefreshNever(String every) {
    return '从未 · $every';
  }

  @override
  String configRefreshAgo(String ago, String every) {
    return '$ago · $every';
  }

  @override
  String configAutoEveryMinutes(int count) {
    return '每 $count 分钟自动刷新';
  }

  @override
  String configAutoEveryHours(int count) {
    return '每 $count 小时自动刷新';
  }

  @override
  String configAutoEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每 $count 天自动刷新',
      one: '每天自动刷新',
    );
    return '$_temp0';
  }

  @override
  String get configRefreshNow => '立即刷新';

  @override
  String configRefreshFailed(String detail) {
    return '刷新失败：$detail';
  }

  @override
  String get configRefreshFailedFallback => '显示的是已有的服务器。';

  @override
  String get configOrganizationPolicyDetail => '这些规则在服务器端设定，无法在此更改。';

  @override
  String configSentBy(String name) {
    return '由$name下发';
  }

  @override
  String get configProviderPolicyDetail => '只读。刷新订阅时会被替换。';

  @override
  String configProviderPolicyDetailSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '另有 $count 条规则无法转换为本应用的格式，未生效。',
      one: '另有 1 条规则无法转换为本应用的格式，未生效。',
    );
    return '只读。刷新订阅时会被替换。$_temp0';
  }

  @override
  String get ruleSetSplitTunneling => '分流';

  @override
  String get ruleSetGeoNotDownloaded => '地理数据库未下载';

  @override
  String get ruleSetGeoNotDownloadedDetail =>
      '下载前 geoip / geosite 规则不会生效（约 25 MB）';

  @override
  String get ruleSetRulesHeader => '规则 — 首个匹配生效';

  @override
  String get homeAddConfiguration => '添加配置';

  @override
  String get homeConfigurationSettings => '配置设置';

  @override
  String homeChipAuto(String state) {
    return '自动 · $state';
  }

  @override
  String homeChipRouting(String state) {
    return '路由 · $state';
  }

  @override
  String homeChipLogs(String state) {
    return '日志 · $state';
  }

  @override
  String get homeStateOn => '开';

  @override
  String get homeStateOff => '关';

  @override
  String get homeAutoPaused => '已暂停';

  @override
  String get homeAutoNotArmed => '未激活';

  @override
  String get homeCheckFailedTitle => '已连接，但没有任何响应';

  @override
  String get homeCheckFailedDetail => '通过此服务器的检测没有收到响应。请换一台服务器，或打开“高级”。';

  @override
  String get homeAutoConnectPausedTitle => '自动连接已暂停';

  @override
  String get homeAutoConnectPausedDetail => '点按“连接”重新激活';

  @override
  String get homeAutoConnectNotArmedTitle => '自动连接尚未激活';

  @override
  String get homeAutoConnectNotArmedDetail => '先连接一次，之后由系统接管';

  @override
  String get homeNoServers => '没有服务器';

  @override
  String get homeGroupAuto => '自动';

  @override
  String homeGroupAutoPicked(String server) {
    return '自动 · $server';
  }

  @override
  String homeAccountUntil(String status, String until) {
    return '$status · 至 $until';
  }

  @override
  String get homeConfiguration => '配置';

  @override
  String get homeServer => '服务器';

  @override
  String get homeChosenByEngine => '由引擎选择';

  @override
  String get homeSwitchingServer => '正在切换服务器…';

  @override
  String get homeGettingServer => '正在获取服务器…';

  @override
  String get statusConnected => '已连接';

  @override
  String homeConnectedClock(String clock) {
    return '已连接 · $clock';
  }

  @override
  String homeStatusAuto(String status) {
    return '$status · 自动';
  }

  @override
  String get statusConnecting => '正在连接…';

  @override
  String get statusError => '错误';

  @override
  String get statusNotConnected => '未连接';

  @override
  String homeGroupRechecks(String summary, int minutes) {
    return '$summary · 每 $minutes 分钟重新检测';
  }

  @override
  String get startCouldntReadFile => '无法读取文件';

  @override
  String get startCouldntReadFileDetail => '请重新打开，或直接粘贴其内容。';

  @override
  String get startAddConnection => '添加连接';

  @override
  String get startSubtitle => '链接、订阅或配置文件';

  @override
  String get startLinkLabel => '链接或订阅';

  @override
  String get startLinkHint => 'vless://…  或  https://…/sub';

  @override
  String startCantUseThis(String reason) {
    return '无法使用 · $reason';
  }

  @override
  String get startOpenConfigFile => '打开配置文件…';

  @override
  String get startOr => '或';

  @override
  String get startSignInToServer => '登录你的服务器';

  @override
  String get startOpenSubscriptionPage => '打开订阅页面';

  @override
  String get signInEnterServerFirst => '请先输入服务器地址';

  @override
  String get signInNoSsoProviders => '此服务器没有 SSO 提供方';

  @override
  String get signInNoSsoProvidersDetail => '请改用用户名和密码登录。';

  @override
  String get signInWith => '登录方式';

  @override
  String get signIn => '登录';

  @override
  String get signInSubtitle => '你的组织或个人服务器';

  @override
  String get signInServerAddress => '服务器地址';

  @override
  String get signInServerHint => 'https://your-server';

  @override
  String get signInUsername => '用户名';

  @override
  String get signInPassword => '密码';

  @override
  String get signInWithSso => '使用 SSO 登录';

  @override
  String get uiNounItem => '项目';

  @override
  String get uiNounServer => '服务器';

  @override
  String get uiNounCountry => '国家或地区';

  @override
  String get uiRemoveFromFavorites => '从收藏中移除';

  @override
  String get uiAddToFavorites => '添加到收藏';

  @override
  String get uiAllNothingMatches => '全部 · 无匹配';

  @override
  String uiAllMatchCount(int shown, int total) {
    return '全部 · $total 项中匹配 $shown 项';
  }

  @override
  String uiNoMatches(String noun, String query, int total) {
    return '没有与“$query”匹配的$noun。清除搜索可查看全部 $total 项。';
  }

  @override
  String get ruleSetModeFullDescription => '全部流量经由 VPN，规则用于定义例外。';

  @override
  String get ruleSetModeSplitDescription => '只有匹配规则的流量经由 VPN，其余直连。';

  @override
  String get ruleSetNoRulesSplit => '无规则：没有流量经由 VPN。请为需要走隧道的内容添加规则。';

  @override
  String get ruleSetNoRulesFull => '无规则：全部流量经由 VPN。';

  @override
  String get ruleSetDownload => '下载';

  @override
  String get ruleKindRuleList => '规则列表';

  @override
  String ruleInactiveNoDatabase(String kind) {
    return '$kind · 未生效 — 无数据库';
  }

  @override
  String ruleInactiveDesktopOnly(String kind) {
    return '$kind · 未生效 — 仅限桌面端';
  }

  @override
  String ruleInactiveListsOff(String kind) {
    return '$kind · 未生效 — 列表已关闭';
  }

  @override
  String ruleInactiveNotDownloaded(String kind) {
    return '$kind · 未生效 — 未下载';
  }

  @override
  String ruleNoResolveKind(String kind) {
    return '$kind · no-resolve';
  }

  @override
  String get ruleTypeDomainSuffix => '域名及其子域名';

  @override
  String get ruleTypeDomainKeyword => '域名包含';

  @override
  String get ruleTypeDomainExact => '精确域名';

  @override
  String get ruleTypeIpCidr => 'IP 段';

  @override
  String get ruleTypeProcessName => '按名称匹配应用';

  @override
  String get ruleTypeGeoip => '按 IP 判断国家或地区';

  @override
  String get ruleTypeGeosite => '域名列表';

  @override
  String get ruleTypeDomainRegex => '域名匹配正则表达式';

  @override
  String get ruleTypeRuleList => '订阅提供的列表';

  @override
  String get rulePickCountry => '请选择国家或地区。';

  @override
  String ruleInvalidValue(String type) {
    return '$type的值无效。';
  }

  @override
  String get ruleMatch => '匹配';

  @override
  String get ruleNotAvailableOnPlatform => '此平台不可用';

  @override
  String get ruleNeedsGeoDatabases => '需要地理数据库';

  @override
  String get ruleAction => '动作';

  @override
  String get ruleActionProxyDescription => '经由 VPN';

  @override
  String get ruleActionDirectDescription => '绕过 VPN';

  @override
  String get ruleActionBlockDescription => '拦截连接';

  @override
  String get ruleAdd => '添加规则';

  @override
  String get ruleEdit => '编辑规则';

  @override
  String get ruleCountry => '国家或地区';

  @override
  String get ruleChoose => '选择…';

  @override
  String get ruleNoResolveDescription => '仅匹配直接使用 IP 的连接，不解析域名';

  @override
  String get ruleValue => '值';

  @override
  String ruleSummaryGeoip(String country) {
    return '发往$country IP 的流量';
  }

  @override
  String ruleSummaryGeosite(String category) {
    return '“$category”域名（GeoSite 列表）';
  }

  @override
  String ruleSummaryProcess(String name) {
    return '“$name”的流量';
  }

  @override
  String ruleSummaryMatching(String value) {
    return '匹配 $value 的流量';
  }

  @override
  String get ruleSummaryProxy => '经由 VPN';

  @override
  String get ruleSummaryDirect => '绕过 VPN 直连';

  @override
  String get ruleSummaryBlock => '被拦截';

  @override
  String ruleSummary(String target, String verb) {
    return '→ $target$verb。';
  }

  @override
  String ruleSetDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get ruleSetDeleteBody => '使用此规则集的配置将改用“默认”。';

  @override
  String get ruleSetDeleteTooltip => '删除规则集';

  @override
  String get ruleSetSimple => '简易';

  @override
  String get ruleSetDownloadSiteLists => '请先下载站点列表';

  @override
  String get ruleSetDownloadSiteListsDetail => '选择服务需要地理数据库（约 25 MB，仅需一次）';

  @override
  String ruleSetAdvancedRules(int count) {
    return '高级规则 · $count';
  }

  @override
  String get ruleSetAdvancedRulesDetail => '优先于下方列表生效 · 在“高级”中编辑';

  @override
  String get ruleSetSearchServices => '搜索服务';

  @override
  String get ruleSetCountriesHeader => '国家和地区';

  @override
  String get ruleSetAddCountry => '添加国家或地区';

  @override
  String get ruleSetServicesHeader => '服务';

  @override
  String get ruleSetAddCategory => '添加类别';

  @override
  String get ruleSetOtherCategoriesHeader => '其他类别';

  @override
  String get ruleSetNothingSelectedSplit => '未选择任何项 · 目前没有流量经由 VPN';

  @override
  String get ruleSetNothingSelectedFull => '未选择任何项 · 全部流量经由 VPN';

  @override
  String ruleSetSelectedSplit(int count) {
    return '已选 $count 项 · 其余全部直连';
  }

  @override
  String ruleSetSelectedFull(int count) {
    return '已选 $count 项 · 它们直连，其余经由 VPN';
  }

  @override
  String get ruleSetOnlySelected => '仅所选';

  @override
  String get ruleSetAllExceptSelected => '所选之外全部';

  @override
  String get ruleSetOnlySelectedDescription => '只有你选择的服务经由 VPN，其余全部直连。';

  @override
  String get ruleSetAllExceptSelectedDescription => '全部流量经由 VPN，你选择的服务直连。';

  @override
  String get ruleSetNew => '新建规则集';

  @override
  String get ruleSetNameHint => '工作';

  @override
  String get ruleSetCreate => '创建';

  @override
  String ruleSetRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条规则',
      zero: '无规则',
    );
    return '$_temp0';
  }

  @override
  String ruleSetUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个配置使用',
      one: '1 个配置使用',
    );
    return '$_temp0';
  }

  @override
  String ruleSetSummaryUsed(String mode, String rules, String used) {
    return '$mode · $rules · $used';
  }

  @override
  String get onDemandEnable => '启用按需连接';

  @override
  String get onDemandEnableSubtitle => '系统应用首个匹配的规则';

  @override
  String get onDemandNoRules => '没有规则。启用按需连接会添加“连接 · 任意网络”。';

  @override
  String get onDemandRulesFootnote => '规则从上到下依次评估。若均不匹配，隧道保持原状。';

  @override
  String get onDemandTagConnect => '连接';

  @override
  String get onDemandTagDisconnect => '断开';

  @override
  String get onDemandTagIgnore => '忽略';

  @override
  String get onDemandNewRule => '新建规则';

  @override
  String get onDemandActionIgnore => '忽略';

  @override
  String get onDemandActionConnectSubtitle => '建立隧道';

  @override
  String get onDemandActionDisconnectSubtitle => '断开隧道';

  @override
  String get onDemandActionIgnoreSubtitle => '隧道保持原状';

  @override
  String get onDemandAny => '任意';

  @override
  String get onDemandNameOptional => '名称（可选）';

  @override
  String get onDemandNameHint => '办公室';

  @override
  String get onDemandNetworkHeader => '网络';

  @override
  String get onDemandNetworkHelpAny => '在任何网络上都会检查此规则：Wi‑Fi、移动网络或有线网络。';

  @override
  String get onDemandNetworkHelpWifi => '设备加入 Wi‑Fi 网络时，系统会检查下方条件并应用此规则。';

  @override
  String get onDemandNetworkHelpCellular => '设备使用移动数据时，系统会检查下方条件并应用此规则。';

  @override
  String get onDemandNetworkHelpEthernet => '设备使用有线网络时，系统会检查下方条件并应用此规则。';

  @override
  String get onDemandConditionsHeader => '条件';

  @override
  String get onDemandWifiNetworks => 'Wi‑Fi 网络';

  @override
  String get onDemandWifiNetwork => 'Wi‑Fi 网络';

  @override
  String get onDemandNetworksUnit => '个网络';

  @override
  String get onDemandWifiNetworksHelp => '精确匹配网络名称。留空则匹配任意 Wi‑Fi。';

  @override
  String get onDemandDnsDomains => 'DNS 搜索域';

  @override
  String get onDemandDnsDomain => 'DNS 搜索域';

  @override
  String get onDemandDomainsUnit => '个域名';

  @override
  String get onDemandDnsDomainsHelp => '当网络的搜索域以某一条目结尾时匹配。';

  @override
  String get onDemandDnsServers => 'DNS 服务器';

  @override
  String get onDemandDnsServer => 'DNS 服务器';

  @override
  String get onDemandServersUnit => '台服务器';

  @override
  String get onDemandDnsServersHelp => '匹配网络的 DNS 服务器；允许使用单个“*”通配符。';

  @override
  String get onDemandUrlProbeHeader => 'URL 探测';

  @override
  String get onDemandUrlOptional => 'URL（可选）';

  @override
  String get onDemandUrlProbeHelp => '仅当此 URL 直接返回 200 且无重定向时，规则才匹配。';

  @override
  String get onDemandNoEntries => '无条目';

  @override
  String onDemandEntriesHeader(int count, String unit) {
    return '$count $unit · 任一匹配即可';
  }

  @override
  String get onDemandConditionIgnored => '此条件将被忽略，规则匹配所选类型的任意网络。';

  @override
  String get onDemandInterfaceAny => '任意网络';

  @override
  String get onDemandInterfaceWifi => 'Wi‑Fi';

  @override
  String get onDemandInterfaceCellular => '移动网络';

  @override
  String get onDemandInterfaceEthernet => '以太网';

  @override
  String onDemandSummarySsid(String values) {
    return 'SSID $values';
  }

  @override
  String onDemandSummaryDomain(String values) {
    return '域名 $values';
  }

  @override
  String onDemandSummaryDns(String values) {
    return 'DNS $values';
  }

  @override
  String get onDemandSummaryProbe => '探测';

  @override
  String get onDemandStatusPaused => '已暂停';

  @override
  String get onDemandStatusAwaitingFirstConnect => '开 · 首次连接后生效';

  @override
  String onDemandStatusOnRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '开 · $count 条规则',
      one: '开 · 1 条规则',
    );
    return '$_temp0';
  }

  @override
  String get onDemandDefaultRuleName => '任何地方';

  @override
  String get statusNoConfiguration => '没有配置';

  @override
  String get menuBarSwitching => '正在切换…';

  @override
  String profilesCouldntGetServer(String label) {
    return '无法获取$label的服务器';
  }

  @override
  String get profilesPreviousServerStillInUse => '仍在使用之前的服务器。';

  @override
  String get profilesCouldntSwitch => '无法切换';

  @override
  String get profilesCouldntSwitchDetail => '隧道保留了之前的配置。请重试或重新连接。';

  @override
  String get profilesNoConfigurationDetail => '添加链接或订阅，或登录你的服务器。';

  @override
  String get profilesNoServers => '此配置没有服务器';

  @override
  String get profilesNoServersDetail => '请刷新，或添加其他配置。';

  @override
  String get profilesTunnelStopped => '隧道已停止';

  @override
  String get connectionCheckTimedOut => '服务器未在规定时间内响应。';

  @override
  String get connectionCheckClosed => '服务器关闭了连接。';

  @override
  String get connectionCheckRefused => '服务器拒绝了连接。';

  @override
  String get connectionCheckNoServer => '没有可测试的服务器：隧道正在运行其他内容。';

  @override
  String get connectionCheckTunnelNotRunning => '隧道未运行。';

  @override
  String get connectionCheckNothingCameBack => '没有任何响应。';

  @override
  String get connectionCheckEngineDidNotAnswer => '引擎没有响应。';

  @override
  String get errorDeviceLimitTitle => '已达设备数量上限';

  @override
  String get errorDeviceLimitDetail =>
      '订阅的设备名额已满，因此返回了占位内容而不是你的服务器。请在订阅中释放一个名额，然后刷新。';

  @override
  String get errorUnreadableSubscriptionTitle => '无法读取此订阅';

  @override
  String get errorUnreadableSubscriptionDetail =>
      '订阅返回的格式本应用无法识别。支持的格式有 base64 链接列表、Clash / mihomo、Xray JSON 和 sing-box。未添加任何内容。';

  @override
  String get errorEmptySubscriptionTitle => '此订阅没有服务器';

  @override
  String errorEmptySubscriptionDetail(String what) {
    return '订阅返回了$what，但其中没有任何服务器。这通常意味着账户已到期或设备名额已满，请联系订阅方。';
  }

  @override
  String errorNoRunnableServersTitle(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '这 $total 台服务器在此均无法运行',
      one: '此处唯一的服务器无法运行',
    );
    return '$_temp0';
  }

  @override
  String errorNoRunnableServersDetail(String kinds) {
    return '它们使用 $kinds，本应用暂不支持。未添加任何内容。';
  }

  @override
  String get errorProviderMessageTitle => '订阅方发来了一条消息';

  @override
  String errorProviderMessageDetail(String lines) {
    return '$lines\n\n这些不是服务器：每一条都没有有效地址，因此未添加任何内容。';
  }

  @override
  String get errorSubjectDefault => '服务器';

  @override
  String get errorServerDidNotAnswerTitle => '服务器没有响应';

  @override
  String errorCouldNotReachDetail(String what) {
    return '无法连接到$what。请检查网络，或选择其他服务器。';
  }

  @override
  String get errorSecureConnectionTitle => '无法建立安全连接';

  @override
  String errorCertificateRejectedDetail(String what) {
    return '$what的证书被拒绝。如果地址无误，可能是服务器配置有问题。';
  }

  @override
  String errorConnectionClosedDetail(String what) {
    return '与$what的连接已关闭。';
  }

  @override
  String get errorWrongCredentialsTitle => '用户名或密码错误';

  @override
  String get errorWrongCredentialsDetail => '请检查后重试。';

  @override
  String get errorSessionExpiredTitle => '会话已过期';

  @override
  String errorSessionExpiredDetail(String what) {
    return '请重新登录$what。';
  }

  @override
  String get errorAccessBlockedTitle => '访问被阻止';

  @override
  String get errorAccessBlockedDetail => '服务器拒绝了此账户。';

  @override
  String get errorNothingAtAddressTitle => '此地址下没有内容';

  @override
  String errorNothingAtAddressDetail(String what) {
    return '请检查链接：$what上没有此账户的配置。';
  }

  @override
  String get errorServerErrorTitle => '服务器返回了错误';

  @override
  String get errorServerErrorDetail => '本地无需处理，请几分钟后重试。';

  @override
  String get errorServerRefusedTitle => '服务器拒绝了请求';

  @override
  String get errorNotALinkTitle => '这不是可识别的链接';

  @override
  String get errorNotALinkDetail =>
      '需要 vless://、vmess://、trojan://、ss:// 或订阅 URL。';

  @override
  String get errorTunnelServiceNotRunningTitle => '隧道服务未运行';

  @override
  String get errorTunnelServiceNotRunningDetail =>
      'AnnoyaTest 会将其安装为名为“AnnoyaTunnel”的 Windows 服务。请重新安装应用，或在“服务”中启动该服务，然后重新连接。';

  @override
  String get errorTunnelServiceStoppedTitle => '隧道服务已停止';

  @override
  String get errorTunnelServiceStoppedDetail =>
      '它会在几秒内自动重启，请重新连接。如果反复出现，可在“设置 → 日志”的隧道日志中查看原因。';

  @override
  String get errorSystemRefusedTunnelTitle => '系统拒绝启动隧道';

  @override
  String get errorSystemRefusedTunnelDetail => '请在系统设置中允许此 VPN 配置，然后重新连接。';

  @override
  String get errorSignInNotFinishedTitle => '登录未完成';

  @override
  String get errorSignInNotFinishedDetail => '浏览器窗口已关闭，或提供方拒绝了登录。';

  @override
  String get errorSomethingWentWrongTitle => '出了点问题';

  @override
  String get errorSomethingWentWrongDetail => '详情请见“设置 → 日志”。';

  @override
  String get errorDeviceNotAcceptedTitle => '订阅不接受此设备';

  @override
  String get errorDeviceNotAcceptedDetail => '它要求提供设备 ID，而本应用已经发送。请联系订阅方的支持人员。';

  @override
  String errorApiTimeout(String baseUrl) {
    return '$baseUrl 没有响应，请检查地址和网络。';
  }

  @override
  String errorApiNetwork(String baseUrl) {
    return '无法连接到 $baseUrl，请检查地址和端口，并确认服务器已启动。';
  }

  @override
  String errorApiTls(String baseUrl) {
    return '与 $baseUrl 通信时发生 TLS 错误。如果服务器使用明文 HTTP，请在地址前加上“http://”。';
  }

  @override
  String errorApiRequest(String baseUrl) {
    return '对 $baseUrl 的请求无法完成，请检查地址后重试。';
  }

  @override
  String get accountExpiredDetail => '请在账户中续订，然后重新连接。';

  @override
  String get accountLimitedTitle => '已达流量上限';

  @override
  String get accountLimitedDetail => '套餐流量已用完，重置后方可继续使用。';

  @override
  String get accountDeactivatedTitle => '访问已被禁用';

  @override
  String get accountDeactivatedDetail => '管理员已停用此账户。';

  @override
  String get accountOnHoldTitle => '订阅尚未开始';

  @override
  String get accountOnHoldDetail => '它将在首次连接时开始，请稍后重试。';

  @override
  String accountOtherStateTitle(String state) {
    return '账户状态：$state';
  }

  @override
  String get accountOtherStateDetail => '此状态下不允许连接。';

  @override
  String get amneziaErrorEmptyAnswerTitle => '网关未返回内容';

  @override
  String get amneziaErrorEmptyAnswerDetail =>
      '网关的响应中没有配置。请重试；如果反复出现，需要此订阅的支持人员进行排查。';

  @override
  String get amneziaErrorCancelledTitle => '耗时过长';

  @override
  String get amneziaErrorCancelledDetail => '网关未在规定时间内响应。请检查网络后重试。';

  @override
  String get amneziaErrorNetworkTitle => '无法连接到网关';

  @override
  String get amneziaErrorNetworkDetail => '网关没有响应。这通常是网络问题，而非订阅问题，请稍后重试。';

  @override
  String get amneziaErrorTimeoutTitle => '网关响应超时';

  @override
  String get amneziaErrorTimeoutDetail => '在允许的时间内没有收到响应。请检查网络后重试。';

  @override
  String get amneziaErrorSslTitle => '连接不受信任';

  @override
  String get amneziaErrorSslDetail => '与网关的安全连接受到了干扰。';

  @override
  String get amneziaErrorConfigTitle => '此版本无法与网关通信';

  @override
  String get amneziaErrorConfigDetail => '构建时未包含网关凭据，因此此版本无法使用此类订阅。';

  @override
  String get amneziaErrorDecryptTitle => '无法读取响应';

  @override
  String get amneziaErrorDecryptDetail => '收到的回复与网关应返回的内容不符，通常是因为所在网络拦截了流量。';

  @override
  String get amneziaErrorInvalidArgumentTitle => '网关请求格式错误';

  @override
  String get amneziaErrorInvalidArgumentDetail =>
      '这是本应用的缺陷，与订阅无关。重启应用通常可以解决；如果反复出现，请将“设置 → 日志”中的日志提供给支持人员。';

  @override
  String get amneziaErrorRefusedTitle => '网关拒绝了请求';

  @override
  String amneziaErrorRefusedCodeDetail(int code) {
    return '网关返回了代码 $code。';
  }

  @override
  String amneziaErrorRefusedHttpDetail(int status) {
    return '网关返回了 HTTP $status。';
  }

  @override
  String get amneziaErrorTooManyRequestsTitle => '请求过于频繁';

  @override
  String get amneziaErrorTooManyRequestsDetail => '网关正在限制此订阅的请求。请等待几分钟后重试。';

  @override
  String get amneziaErrorTrialUsedTitle => '试用已被使用';

  @override
  String get amneziaErrorTrialUsedDetail => '此地址已经激活过试用。';

  @override
  String get amneziaErrorDeviceLimitDetail =>
      '此订阅已安装在允许的最大设备数量上。请从订阅中移除一台设备，然后重试。';

  @override
  String get amneziaErrorNotFoundTitle => '未找到订阅';

  @override
  String get amneziaErrorNotFoundDetail => '网关无法识别此密钥。请确认已完整粘贴。';

  @override
  String get amneziaErrorNewerClientTitle => '网关要求更新的客户端';

  @override
  String get amneziaErrorNewerClientDetail => '网关拒绝了本应用的当前版本。更新应用后即可恢复使用。';

  @override
  String get amneziaErrorCaptchaPass => '请在此订阅来源的应用中完成验证，然后在此处刷新。';

  @override
  String get amneziaErrorCaptchaExpiredTitle => 'CAPTCHA 已过期';

  @override
  String get amneziaErrorCaptchaRejectedTitle => 'CAPTCHA 未通过';

  @override
  String get amneziaErrorCaptchaAskedTitle => '网关要求完成 CAPTCHA 验证';

  @override
  String amneziaErrorCaptchaAskedDetail(String pass) {
    return '本应用无法显示验证码。$pass';
  }

  @override
  String get amneziaErrorNotActiveTitle => '订阅未激活';

  @override
  String get amneziaErrorNotActiveDetail => '网关中没有与此密钥对应的有效订阅。';

  @override
  String get amneziaErrorLostKeyTitle => '此订阅的密钥已丢失';

  @override
  String get amneziaErrorLostKeyDetail => '请移除此配置后重新添加。';

  @override
  String get amneziaErrorFreeTierUnsupported =>
      '此订阅为免费版，其网关在下发配置前要求完成 CAPTCHA 验证，而本应用无法显示验证码。请使用其来源应用，或在此添加付费密钥。';

  @override
  String get importNotAKeyTitle => '这不是订阅密钥';

  @override
  String get importNotAKeyDetail => '需要来自订阅的 vpn:// 密钥。';

  @override
  String importKeyUnsupportedTitle(String name) {
    return '此处不支持$name';
  }

  @override
  String importImportedName(int count) {
    return '已导入（$count）';
  }

  @override
  String get importFormatLinks => '链接列表';

  @override
  String get importFormatClash => 'Clash / mihomo 订阅';

  @override
  String get importFormatXray => 'Xray JSON 订阅';

  @override
  String get importFormatSingbox => 'sing-box 订阅';

  @override
  String get importFormatUnknown => '无法识别的内容';

  @override
  String importDetectedAmneziaKey(String name) {
    return '$name · 订阅密钥';
  }

  @override
  String importDetectedServer(String type, String label) {
    return '$type 服务器 · $label';
  }

  @override
  String importDetectedSubscriptionUrl(String host) {
    return '订阅 URL · $host';
  }

  @override
  String importDetectedSingleServer(String label) {
    return '服务器 · $label';
  }

  @override
  String importDetectedSubscriptionText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台服务器',
      one: '1 台服务器',
    );
    return '订阅 · $_temp0';
  }

  @override
  String get importUnusableNotAmneziaKey => '不是 Amnezia 订阅密钥';

  @override
  String importUnusableNotSupported(String what) {
    return '不支持 $what';
  }

  @override
  String importUnusableTransportNotSupported(String scheme, String transport) {
    return '不支持基于 $transport 的 $scheme';
  }

  @override
  String importUnusableLinkUnreadable(String scheme) {
    return '无法读取 $scheme:// 链接';
  }

  @override
  String get importUnusableNotALink => '不是链接或订阅';

  @override
  String get catalogGroupStreaming => '流媒体';

  @override
  String get catalogGroupMessengers => '即时通讯';

  @override
  String get catalogGroupSocial => '社交';

  @override
  String get catalogGroupOther => '其他';

  @override
  String proxyGroupUrlTest(int count) {
    return '$count 台中延迟最低的';
  }

  @override
  String proxyGroupFallback(int count) {
    return '$count 台中首个可用的 · 按顺序';
  }

  @override
  String proxyGroupLoadBalance(int count) {
    return '分散到 $count 台';
  }

  @override
  String proxyGroupRelay(int count) {
    return '$count 台链式代理';
  }
}
