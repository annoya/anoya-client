// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get commonSettings => 'Ajustes';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get commonOn => 'Activado';

  @override
  String get commonOff => 'Desactivado';

  @override
  String get commonConnect => 'Conectar';

  @override
  String get commonDisconnect => 'Desconectar';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonAll => 'TODOS';

  @override
  String get commonFavorites => 'FAVORITOS';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsCloudSync => 'Sincronización con iCloud';

  @override
  String get settingsCloudSyncing => 'Sincronizando…';

  @override
  String settingsCloudSynced(String ago) {
    return 'Sincronizado $ago';
  }

  @override
  String settingsCloudSyncFailed(String ago) {
    return 'Error · última sincronización $ago';
  }

  @override
  String get settingsCloudSyncFailedNever => 'Error de sincronización';

  @override
  String get settingsCloudSyncUnavailable =>
      'Inicia sesión en iCloud en este dispositivo primero';

  @override
  String get settingsCloudSyncWaitingForKey =>
      'Esperando la clave del Llavero de iCloud';

  @override
  String get commonClear => 'Borrar';

  @override
  String get commonJustNow => 'ahora mismo';

  @override
  String get settingsSectionConfigurations => 'CONFIGURACIONES';

  @override
  String get settingsSectionConnection => 'CONEXIÓN';

  @override
  String get settingsSectionRouting => 'ENRUTAMIENTO';

  @override
  String get settingsSectionGeneral => 'GENERAL';

  @override
  String get settingsSectionDiagnostics => 'DIAGNÓSTICO';

  @override
  String get settingsSectionAbout => 'ACERCA DE';

  @override
  String get settingsConfigurations => 'Configuraciones';

  @override
  String settingsConfigurationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count configuraciones',
      one: '1 configuración',
    );
    return '$_temp0';
  }

  @override
  String get uiNounConfiguration => 'configuración';

  @override
  String get settingsAutoConnect => 'Conexión automática';

  @override
  String get settingsAutoConnectSubtitle => 'Conectar al iniciar el equipo';

  @override
  String get onDemandTitle => 'Bajo demanda';

  @override
  String get settingsDisconnectOnSleep => 'Desconectar al suspender';

  @override
  String get settingsDisconnectOnSleepSubtitle =>
      'Cerrar el túnel cuando el dispositivo se suspende';

  @override
  String get settingsAlwaysOnSubtitle =>
      'Un ajuste del sistema: se configura en los ajustes de Android';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsConnectionCheckOn => 'Comprobación de conexión · activada';

  @override
  String get settingsConnectionCheckOff =>
      'Comprobación de conexión · desactivada';

  @override
  String get settingsLanDirect => 'Red local directa';

  @override
  String get settingsLanDirectSubtitle =>
      'El tráfico de la LAN no pasa por la VPN';

  @override
  String get ruleSetsTitle => 'Conjuntos de reglas';

  @override
  String settingsRuleSetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conjuntos',
      one: '1 conjunto',
    );
    return '$_temp0';
  }

  @override
  String get settingsDefaultDns => 'DNS predeterminado';

  @override
  String settingsDefaultDnsSubtitle(String name) {
    return '$name · se usa cuando la configuración no trae ninguno';
  }

  @override
  String get settingsDnsCustom => 'Personalizado…';

  @override
  String get settingsDnsCustomSubtitle =>
      'cualquier dirección que acepte el motor';

  @override
  String get settingsDnsResolverLabel => 'Servidor DNS';

  @override
  String get settingsDnsUseCloudflare => 'Usar Cloudflare';

  @override
  String settingsGeoDownloaded(String size) {
    return 'descargado · $size';
  }

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsThemeSystemSubtitle => 'Seguir el ajuste del dispositivo';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutEngine => 'Motor';

  @override
  String get aboutVersionCopied => 'Versión copiada';

  @override
  String get aboutTermsOfService => 'Términos del servicio';

  @override
  String get aboutPrivacyPolicy => 'Política de privacidad';

  @override
  String get aboutNotPublishedYet => 'Aún no publicado';

  @override
  String get uiCouldNotOpenPage => 'No se pudo abrir la página.';

  @override
  String get advancedSectionConnectionCheck => 'COMPROBACIÓN DE CONEXIÓN';

  @override
  String get advancedSectionLastCheck => 'ÚLTIMA COMPROBACIÓN';

  @override
  String get advancedCheckAfterConnecting => 'Comprobar tras conectar';

  @override
  String get advancedCheckAfterConnectingSubtitle =>
      'Descarga una página a través del servidor y mide el tiempo de respuesta';

  @override
  String get advancedTestUrl => 'URL de prueba';

  @override
  String get advancedUrlLabel => 'URL';

  @override
  String get advancedUseDefault => 'Usar la predeterminada';

  @override
  String get advancedInvalidUrl =>
      'Introduce una dirección http:// o https://.';

  @override
  String get advancedGiveUpAfter => 'Abandonar tras';

  @override
  String advancedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get advancedTestNow => 'Probar ahora';

  @override
  String get advancedNeedsTunnelNote =>
      'La solicitud pasa por el motor en ejecución, así que el túnel tiene que estar activo para probarla.';

  @override
  String get advancedCheckScopeNote =>
      'La solicitud pasa por el propio servidor, así que las reglas de enrutamiento no le afectan. Demuestra que el servidor deja pasar tráfico, no que tu tráfico pase por él.';

  @override
  String get advancedNoAnswer => 'Sin respuesta';

  @override
  String advancedNoAnswerDetail(String failure) {
    return '$failure El túnel está activo, así que el problema está en el servidor o en la red más allá de él.';
  }

  @override
  String get advancedTrafficGettingThrough => 'El tráfico pasa';

  @override
  String advancedAnsweredIn(int ms) {
    return 'Respondió en $ms ms';
  }

  @override
  String advancedResultVia(String ago, String via) {
    return '$ago · a través de $via';
  }

  @override
  String commonMinutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String advancedHoursAgo(int count) {
    return 'hace $count h';
  }

  @override
  String get alwaysOnTitle => 'VPN siempre activa';

  @override
  String get alwaysOnStartedBySystem => 'Iniciada por el sistema';

  @override
  String get alwaysOnStartedBySystemSubtitle =>
      'Al arrancar y cada vez que el túnel se cae';

  @override
  String get alwaysOnBlockWithoutVpn => 'Bloquear conexiones sin VPN';

  @override
  String get alwaysOnBlockWithoutVpnSubtitle =>
      'El «kill switch» del sistema, en la misma pantalla';

  @override
  String get alwaysOnNote =>
      'Este ajuste pertenece a Android, así que está en los ajustes del sistema: Red e Internet → VPN → el engranaje junto a esta app. El sistema inicia la última configuración que se usó.';

  @override
  String get alwaysOnOpenSystemSettings =>
      'Abrir los ajustes de VPN del sistema';

  @override
  String get dnsTitle => 'DNS';

  @override
  String get dnsSectionInEffect => 'EN USO';

  @override
  String get dnsSectionDropped => 'DESCARTADOS';

  @override
  String get dnsParallelNote =>
      'Se consultan a la vez; gana la primera respuesta.';

  @override
  String get dnsFallbackNote =>
      'Esta configuración no indica ningún servidor DNS propio, así que la app usa el predeterminado. Cámbialo en Ajustes › DNS predeterminado.';

  @override
  String get dnsProviderNote =>
      'Lo eligió quien creó esta configuración y cambia con ella.';

  @override
  String get dnsProxyResolvedDirectlyNote =>
      'La dirección del servidor a través del que te conectas siempre se resuelve directamente. Tiene que ser así: de lo contrario nada podría alcanzar el túnel.';

  @override
  String dnsResolverSubtitle(String protocol, String origin) {
    return '$protocol · $origin';
  }

  @override
  String get dnsPinIgnoredTooltip =>
      'Esta configuración pedía una salida que esta app no crea, así que la petición se descartó y el servidor DNS se alcanza directamente.';

  @override
  String get dnsOriginAppDefault => 'predeterminado de la app';

  @override
  String get dnsOriginSubscription => 'de tu suscripción';

  @override
  String get dnsOriginOrganisation => 'de tu organización';

  @override
  String get dnsOriginConfiguration => 'de esta configuración';

  @override
  String get dnsRoutingDirect => 'directo';

  @override
  String get dnsRoutingFollowsRules => 'sigue tus reglas';

  @override
  String get dnsRoutingThroughTunnel => 'a través del túnel';

  @override
  String get dnsProtocolDoh => 'DNS sobre HTTPS';

  @override
  String get dnsProtocolDot => 'DNS sobre TLS';

  @override
  String get dnsProtocolDoq => 'DNS sobre QUIC';

  @override
  String get dnsProtocolPlain => 'Sin cifrar';

  @override
  String get dnsDropMalformed =>
      'No es una dirección de servidor DNS. Nada de una suscripción entra en la configuración del motor sin comprobarse.';

  @override
  String get dnsDropUnknownScheme =>
      'El motor no conoce este esquema. Mantenerlo habría invalidado toda la configuración, no solo esta línea.';

  @override
  String get dnsDropCannotCarry =>
      'El DNS sin cifrar no puede viajar a través de este servidor, y enviarlo fuera del túnel mostraría a tu red cada sitio que visitas.';

  @override
  String dnsDropTooMany(int max) {
    return 'Supera los $max que se le pasan al motor. Los consulta todos a la vez, así que una lista más larga cuesta tiempo sin responder mejor.';
  }

  @override
  String get dnsPresetQuad9Note => 'filtra dominios maliciosos conocidos';

  @override
  String get dnsPresetAdGuardNote => 'filtra anuncios y rastreadores';

  @override
  String get dnsErrorNotResolverAddress =>
      'No es una dirección de servidor DNS.';

  @override
  String get dnsErrorAddressedByName =>
      'Está indicado por nombre, así que habría que resolverlo antes de que pudiera resolver nada. Usa su dirección IP.';

  @override
  String get geoTitle => 'GeoIP y GeoSite';

  @override
  String get geoSectionDatabases => 'BASES DE DATOS';

  @override
  String get geoSectionUpdates => 'ACTUALIZACIONES';

  @override
  String get geoGeoipSource => 'Origen de GeoIP';

  @override
  String get geoGeositeSource => 'Origen de GeoSite';

  @override
  String get geoDownloadUrlLabel => 'URL de descarga';

  @override
  String get geoResetToDefault => 'Restablecer valor predeterminado';

  @override
  String get geoNotDownloaded => 'no descargado';

  @override
  String get geoNever => 'nunca';

  @override
  String commonDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String commonHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get geoLastUpdated => 'Última actualización';

  @override
  String get geoAutoUpdate => 'Actualización automática';

  @override
  String get geoAutoUpdateSubtitle => 'Semanal, si ya está descargado';

  @override
  String get geoUpdateNow => 'Actualizar ahora';

  @override
  String get geoDownload => 'Descargar (~25 MB)';

  @override
  String get geoDatabaseHostSubject => 'el servidor de las bases de datos';

  @override
  String get geositeCategoryLabel => 'Categoría';

  @override
  String geositeDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dominios',
      one: '1 dominio',
    );
    return '$_temp0';
  }

  @override
  String get geositeNoCategories =>
      'No hay categorías: descarga primero las bases de datos geográficas.';

  @override
  String uiNothingMatches(String query) {
    return 'Nada coincide con «$query».';
  }

  @override
  String get geositeSectionPopular => 'POPULARES';

  @override
  String geositeSectionAll(int count) {
    return 'TODAS · $count';
  }

  @override
  String geositeSectionAllMatch(int count, int total) {
    return 'TODAS · $count DE $total COINCIDEN';
  }

  @override
  String get logsTitle => 'Registros';

  @override
  String get logsSectionCollection => 'RECOPILACIÓN';

  @override
  String get logsSectionTunnel => 'TÚNEL';

  @override
  String get logsSectionApp => 'APP';

  @override
  String get logsCollect => 'Recopilar registros';

  @override
  String get logsCollectSubtitle =>
      'Desactivado: la app, el túnel y el núcleo dejan de escribir. Los archivos existentes siguen pudiendo leerse.';

  @override
  String get logsTunnel => 'Túnel';

  @override
  String get logsTunnelSubtitle => 'Eventos de la Network Extension';

  @override
  String get logsCore => 'Núcleo (mihomo)';

  @override
  String get logsCoreSubtitle =>
      'Registro del motor: conexiones, DNS, enrutamiento';

  @override
  String get logsApplication => 'Aplicación';

  @override
  String get logsApplicationSubtitle => 'Eventos del lado del cliente';

  @override
  String get logsSaveAllZip => 'Guardar todos los registros (.zip)';

  @override
  String get logsSaveAll => 'Guardar todos los registros';

  @override
  String get logsSaveToFile => 'Guardar en un archivo…';

  @override
  String get logsSaveToFileSubtitle => 'Elige una carpeta en este dispositivo';

  @override
  String get logsShare => 'Compartir…';

  @override
  String get logsShareSubtitle => 'Enviar el archivo a algún sitio';

  @override
  String get logsSaveDialogTitle => 'Guardar registros';

  @override
  String logsSavedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String get logsClearAll => 'Borrar todos los registros';

  @override
  String get logsClearAllQuestion => '¿Borrar todos los registros?';

  @override
  String get logsClearAllContent =>
      'Los registros de la app, el túnel y el núcleo se eliminarán de este dispositivo.';

  @override
  String get logsCleared => 'Registros borrados.';

  @override
  String get logsAppLogClearedOnly =>
      'Registro de la app borrado. Los del túnel y el núcleo requieren la VPN conectada.';

  @override
  String get logsNoLog => 'Sin registro.';

  @override
  String get logsNoLogYet => 'Aún no hay registro.';

  @override
  String get logsEmpty => 'Vacío';

  @override
  String get logsUnavailable =>
      'Los registros solo están disponibles mientras el túnel está en ejecución.\n(El proceso del túnel guarda sus registros en su lado y los transmite a la app por IPC.)';

  @override
  String get commonTryAgain => 'Intentar de nuevo';

  @override
  String configKindSelfhosted(String servers) {
    return 'Autoalojado · $servers';
  }

  @override
  String configKindSubscription(String servers, String groups) {
    return 'Suscripción · $servers$groups';
  }

  @override
  String get configKindSubscriptionPlain => 'Suscripción';

  @override
  String get configKindSingleServer => 'Servidor único';

  @override
  String commonServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '1 servidor',
    );
    return '$_temp0';
  }

  @override
  String configServersOfOffered(int ours, int offered) {
    String _temp0 = intl.Intl.pluralLogic(
      offered,
      locale: localeName,
      other: '$ours de $offered servidores',
      one: '$ours de 1 servidor',
    );
    return '$_temp0';
  }

  @override
  String configGroupsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' · $count grupos',
      one: ' · 1 grupo',
    );
    return '$_temp0';
  }

  @override
  String get configSource => 'Origen';

  @override
  String get configSourceViaFallback =>
      'La última actualización usó la dirección de respaldo de la suscripción';

  @override
  String get configCouldNotOpenLink => 'No se pudo abrir el enlace.';

  @override
  String get configLinkCopied => 'Enlace copiado';

  @override
  String configUnsupportedTitle(int skipped, int offered) {
    return '$skipped de $offered servidores no compatibles';
  }

  @override
  String configUnsupportedDetail(String kinds, int available) {
    return 'Usan $kinds, que esta app aún no puede ejecutar. Los otros $available están disponibles.';
  }

  @override
  String get configSetActive => 'Activar';

  @override
  String get configRemoveConfiguration => 'Quitar configuración';

  @override
  String configRemoveTitle(String name) {
    return '¿Quitar $name?';
  }

  @override
  String get configRemoveDetail =>
      'Esta configuración se quitará de este dispositivo.';

  @override
  String get configSectionSubscription => 'SUSCRIPCIÓN';

  @override
  String get configRanUntil => 'Válida hasta';

  @override
  String get configRunsUntil => 'Válida hasta';

  @override
  String get configDevices => 'Dispositivos';

  @override
  String configDevicesUsed(int active, int max) {
    return '$active de $max en uso';
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
      other: 'quedan $count días',
      one: 'queda 1 día',
    );
    return '$date · $_temp0';
  }

  @override
  String get accountExpiredTitle => 'Suscripción caducada';

  @override
  String get configSubscriptionExpiredDetail =>
      'Renueva la suscripción y luego actualiza esta configuración.';

  @override
  String get configSectionThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get configDeviceIdentifiedSubtitle =>
      'Identificado ante tu suscripción, que cuenta los dispositivos';

  @override
  String get configDeviceId => 'ID del dispositivo';

  @override
  String get configDeviceHintAmnezia =>
      'Tu suscripción cuenta los dispositivos por este ID. Se genera una vez y se conserva, así que reconectar no gasta plazas, pero una reinstalación toma una nueva.';

  @override
  String get configDeviceHintPanel =>
      'Tu suscripción cuenta los dispositivos por un ID que esta app genera una vez y conserva. Reinstalarla crea uno nuevo, que ocupa otra plaza.';

  @override
  String configCopiedTitle(String title) {
    return '$title copiado';
  }

  @override
  String configDnsSummary(String host, String routing) {
    return '$host · $routing';
  }

  @override
  String configDnsMore(int count) {
    return ' · +$count más';
  }

  @override
  String configDnsDropped(int count) {
    return '$count descartados';
  }

  @override
  String get configDnsByApp => 'DNS de la app';

  @override
  String configDnsOrigin(String origin) {
    return 'DNS $origin';
  }

  @override
  String configDnsRefused(int count) {
    return 'DNS: $count rechazados';
  }

  @override
  String get configRouting => 'Enrutamiento';

  @override
  String get configRuleSet => 'Conjunto de reglas';

  @override
  String get configRuleSetDefault => 'Predeterminado';

  @override
  String get configRuleLists => 'Listas de reglas';

  @override
  String get ruleSetModeSplit => 'Dividido';

  @override
  String get ruleSetModeFull => 'Túnel completo';

  @override
  String ruleSetSummary(String mode, String rules) {
    return '$mode · $rules';
  }

  @override
  String get ruleSetNoRules => 'sin reglas';

  @override
  String get configNoExceptions => 'sin excepciones';

  @override
  String configRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: '1 regla',
    );
    return '$_temp0';
  }

  @override
  String configSkippedNotSupported(int count) {
    return '$count no compatibles';
  }

  @override
  String configListsUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas no disponibles',
      one: '1 lista no disponible',
    );
    return '$_temp0';
  }

  @override
  String configRulesNeedLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count necesitan sus listas',
      one: '1 necesita sus listas',
    );
    return '$_temp0';
  }

  @override
  String configDownloadingLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargando $count listas…',
      one: 'Descargando una lista…',
    );
    return '$_temp0';
  }

  @override
  String configRuleListsOff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas las necesitan',
      one: '1 regla las necesita',
    );
    return 'Desactivadas · $_temp0';
  }

  @override
  String get configChecking => 'Comprobando…';

  @override
  String get configNoneDownloadedYet => 'Aún no se ha descargado ninguna';

  @override
  String configListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String configListsDownloadedOf(int have, int total) {
    return '$have de $total descargadas';
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
      other: 'No se pudieron descargar $count listas',
      one: 'No se pudo descargar una lista',
    );
    return '$_temp0';
  }

  @override
  String configListsFailedDetail(int count, String names, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names de $hosts: las reglas que las usan no se aplican.',
      one: '$names de $hosts: la regla que la usa no se aplica.',
    );
    return '$_temp0';
  }

  @override
  String configReplacedBy(String name) {
    return 'Sustituido por $name';
  }

  @override
  String get configRoutingOffSummary => 'Desactivado · todo a través de la VPN';

  @override
  String get configManagedByOrganization => 'Gestionado por tu organización';

  @override
  String configManagedSummary(String mode, int count) {
    return '$mode · $count reglas, definidas en el servidor';
  }

  @override
  String configSetByOrganization(String mode) {
    return '$mode · definido por tu organización';
  }

  @override
  String get configSectionOrganizationRouting =>
      'ENRUTAMIENTO DE LA ORGANIZACIÓN';

  @override
  String get configSectionSubscriptionRouting =>
      'ENRUTAMIENTO DE LA SUSCRIPCIÓN';

  @override
  String get configSectionDeviceRouting => 'ENRUTAMIENTO DEL DISPOSITIVO';

  @override
  String get configOrganizationRoutingNote =>
      'Tu organización define esta política y la aplica. Puedes ver en qué consiste; los cambios se hacen de su lado.';

  @override
  String get configSubscriptionRoutes => 'las rutas de la suscripción';

  @override
  String get configSubscriptionRoutingNote =>
      'Desactiva el interruptor para usar tu propio conjunto de reglas. Tu suscripción no puede imponerlo en ningún caso.';

  @override
  String get configDeviceRoutingNote =>
      'Los conjuntos de reglas se comparten entre todas las configuraciones; el interruptor es por configuración, así que una suscripción de trabajo y una personal pueden usar el mismo conjunto de forma distinta.';

  @override
  String get configSectionDetails => 'DETALLES';

  @override
  String get configGetSupport => 'Obtener ayuda';

  @override
  String get configNoPlanDetails =>
      'Tu suscripción no informó de los detalles del plan.';

  @override
  String configUsedNoLimit(String used) {
    return 'Usado: $used · sin límite';
  }

  @override
  String configTrafficOf(String used, String total) {
    return 'Tráfico: $used de $total';
  }

  @override
  String get configNoExpiryDate => 'No se indicó fecha de caducidad';

  @override
  String configExpiredOn(String date) {
    return 'Caducó el $date';
  }

  @override
  String configActiveUntil(String date) {
    return 'Activa hasta el $date';
  }

  @override
  String configPlanLine(String when) {
    return '$when · lo que informa la suscripción, sin verificar aquí';
  }

  @override
  String get configAccount => 'Cuenta';

  @override
  String configStatus(String status) {
    return 'Estado: $status';
  }

  @override
  String configStatusOnHold(String status) {
    return 'Estado: $status · empieza con el primer uso';
  }

  @override
  String configStatusExpires(String status, String date) {
    return 'Estado: $status · caduca el $date';
  }

  @override
  String get configLastRefreshed => 'Última actualización';

  @override
  String get configRefreshEvery => 'Actualizar cada';

  @override
  String get configHours => 'Horas';

  @override
  String get configRefreshAsSubscriptionAsks => 'Según indique la suscripción';

  @override
  String get configRefreshEnterWholeHours =>
      'Introduce un número entero de horas.';

  @override
  String configRefreshNever(String every) {
    return 'nunca · $every';
  }

  @override
  String configRefreshAgo(String ago, String every) {
    return '$ago · $every';
  }

  @override
  String configAutoEveryMinutes(int count) {
    return 'auto cada $count min';
  }

  @override
  String configAutoEveryHours(int count) {
    return 'auto cada $count h';
  }

  @override
  String configAutoEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'auto cada $count días',
      one: 'auto cada día',
    );
    return '$_temp0';
  }

  @override
  String get configRefreshNow => 'Actualizar ahora';

  @override
  String configRefreshFailed(String detail) {
    return 'No se pudo actualizar: $detail';
  }

  @override
  String get configRefreshFailedFallback =>
      'se muestran los servidores que ya teníamos.';

  @override
  String get configOrganizationPolicyDetail =>
      'Estas reglas se definen en el servidor y no pueden cambiarse aquí.';

  @override
  String configSentBy(String name) {
    return 'Enviadas por $name';
  }

  @override
  String get configProviderPolicyDetail =>
      'Solo lectura. Al actualizar la suscripción se sustituyen.';

  @override
  String configProviderPolicyDetailSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count reglas más no pudieron traducirse para esta app y no se aplican.',
      one: '1 regla más no pudo traducirse para esta app y no se aplica.',
    );
    return 'Solo lectura. Al actualizar la suscripción se sustituyen. $_temp0';
  }

  @override
  String get ruleSetSplitTunneling => 'Túnel dividido';

  @override
  String get ruleSetGeoNotDownloaded =>
      'Bases de datos geográficas no descargadas';

  @override
  String get ruleSetGeoNotDownloadedDetail =>
      'las reglas geoip / geosite están inactivas hasta entonces (~25 MB)';

  @override
  String get ruleSetRulesHeader => 'REGLAS — GANA LA PRIMERA COINCIDENCIA';

  @override
  String get homeAddConfiguration => 'Añadir configuración';

  @override
  String get homeConfigurationSettings => 'Ajustes de la configuración';

  @override
  String homeChipAuto(String state) {
    return 'Auto · $state';
  }

  @override
  String homeChipRouting(String state) {
    return 'Enrutamiento · $state';
  }

  @override
  String homeChipLogs(String state) {
    return 'Registros · $state';
  }

  @override
  String get homeStateOn => 'activado';

  @override
  String get homeStateOff => 'desactivado';

  @override
  String get homeAutoPaused => 'en pausa';

  @override
  String get homeAutoNotArmed => 'sin armar';

  @override
  String get homeCheckFailedTitle => 'Conectado, pero sin respuesta';

  @override
  String get homeCheckFailedDetail =>
      'La comprobación no obtuvo respuesta a través de este servidor. Prueba otro o abre Avanzado.';

  @override
  String get homeAutoConnectPausedTitle => 'Conexión automática en pausa';

  @override
  String get homeAutoConnectPausedDetail =>
      'Pulsa Conectar para armarla de nuevo';

  @override
  String get homeAutoConnectNotArmedTitle =>
      'Conexión automática aún sin armar';

  @override
  String get homeAutoConnectNotArmedDetail =>
      'Conéctate una vez para que el sistema tome el control';

  @override
  String get homeNoServers => 'Sin servidores';

  @override
  String get homeGroupAuto => 'auto';

  @override
  String homeGroupAutoPicked(String server) {
    return 'auto · $server';
  }

  @override
  String homeAccountUntil(String status, String until) {
    return '$status · hasta el $until';
  }

  @override
  String get homeConfiguration => 'Configuración';

  @override
  String get homeServer => 'Servidor';

  @override
  String get homeChosenByEngine => 'ELEGIDO POR EL MOTOR';

  @override
  String get homeSwitchingServer => 'Cambiando de servidor…';

  @override
  String get homeGettingServer => 'Obteniendo el servidor…';

  @override
  String get statusConnected => 'Conectado';

  @override
  String homeConnectedClock(String clock) {
    return 'Conectado · $clock';
  }

  @override
  String homeStatusAuto(String status) {
    return '$status · auto';
  }

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String get statusError => 'Error';

  @override
  String get statusNotConnected => 'Sin conexión';

  @override
  String homeGroupRechecks(String summary, int minutes) {
    return '$summary · vuelve a comprobar cada $minutes min';
  }

  @override
  String get startCouldntReadFile => 'No se pudo leer el archivo';

  @override
  String get startCouldntReadFileDetail =>
      'Intenta abrirlo de nuevo o pega su contenido.';

  @override
  String get startAddConnection => 'Añadir una conexión';

  @override
  String get startSubtitle => 'Enlace, suscripción o archivo de configuración';

  @override
  String get startLinkLabel => 'Enlace o suscripción';

  @override
  String get startLinkHint => 'vless://…  o  https://…/sub';

  @override
  String get startPaste => 'Pegar';

  @override
  String get startClipboardEmpty => 'El portapapeles está vacío';

  @override
  String get secretsInFileNotice =>
      'No hay llavero en este sistema: los datos de acceso se guardan en un archivo que solo tu cuenta puede leer.';

  @override
  String get ruleSetImport => 'Importar un conjunto de reglas';

  @override
  String get ruleSetImportFromFile => 'Desde un archivo…';

  @override
  String get ruleSetImportFromFileSubtitle =>
      'Anoya, Clash / mihomo, Shadowrocket, Surge, Happ';

  @override
  String get ruleSetImportFromClipboard => 'Pegar del portapapeles';

  @override
  String get ruleSetImportFromClipboardSubtitle =>
      'Un conjunto de reglas o un enlace happ://routing';

  @override
  String get ruleSetImportScanSubtitle => 'Desde otro dispositivo';

  @override
  String get ruleSetImportScanHint =>
      'Un conjunto de reglas de Anoya o un perfil de enrutamiento de Happ';

  @override
  String get ruleSetImportNotARuleSet => 'no es un conjunto de reglas';

  @override
  String get ruleSetImportUnreadable =>
      'No se pudo leer un conjunto de reglas. Anoya lee sus propios archivos, las reglas de Clash / mihomo y Shadowrocket / Surge, y los perfiles de enrutamiento de Happ.';

  @override
  String get ruleSetImportTitle => 'Importar conjunto de reglas';

  @override
  String get ruleSetImportSourceAnoya => 'Conjunto de reglas de Anoya';

  @override
  String get ruleSetImportSourceClash => 'Reglas de Clash / mihomo';

  @override
  String get ruleSetImportSourceSurge => 'Reglas de Shadowrocket / Surge';

  @override
  String get ruleSetImportSourceHapp => 'Perfil de enrutamiento de Happ';

  @override
  String get ruleSetImportAsIs => 'Nada que convertir';

  @override
  String get ruleSetImportMigrated =>
      'Migrado a un conjunto de reglas de Anoya';

  @override
  String ruleSetImportRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: '1 regla',
      zero: 'Sin reglas',
    );
    return '$_temp0';
  }

  @override
  String ruleSetImportDirect(int count) {
    return '$count directas';
  }

  @override
  String ruleSetImportProxy(int count) {
    return '$count por la VPN';
  }

  @override
  String ruleSetImportBlock(int count) {
    return '$count bloqueadas';
  }

  @override
  String get ruleSetImportSkipped => 'NO TRANSFERIDO';

  @override
  String get ruleSetImportSkipDns => 'Servidores DNS';

  @override
  String get ruleSetImportSkipDnsDetail =>
      'En Anoya se configuran por cada configuración';

  @override
  String get ruleSetImportSkipGeo => 'Enlaces a bases geo';

  @override
  String get ruleSetImportSkipGeoDetail => 'Anoya usa las suyas, en Ajustes';

  @override
  String ruleSetImportSkipLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas con listas por enlace',
      one: '1 regla con una lista por enlace',
    );
    return '$_temp0';
  }

  @override
  String get ruleSetImportSkipListsDetail =>
      'Las listas por enlace no forman parte de tus propios conjuntos';

  @override
  String ruleSetImportSkipOther(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas que Anoya no puede ejecutar',
      one: '1 regla que Anoya no puede ejecutar',
    );
    return '$_temp0';
  }

  @override
  String get ruleSetImportAdd => 'Añadir conjunto';

  @override
  String ruleSetImportAdded(String name) {
    return 'Conjunto «$name» añadido';
  }

  @override
  String get ruleSetImportDefaultName => 'Conjunto importado';

  @override
  String get ruleSetExport => 'Exportar';

  @override
  String ruleSetExportTitle(String name) {
    return 'Exportar «$name»';
  }

  @override
  String get ruleSetExportShare => 'Compartir…';

  @override
  String get ruleSetExportShareSubtitle =>
      'Enviar el archivo a otra app o dispositivo';

  @override
  String get ruleSetExportSave => 'Guardar en un archivo…';

  @override
  String get ruleSetExportCopy => 'Copiar al portapapeles';

  @override
  String get ruleSetExportCopySubtitle => 'Como enlace anoya://ruleset';

  @override
  String get ruleSetExportQr => 'Mostrar un código QR';

  @override
  String get ruleSetExportQrSubtitle =>
      'Escanéalo en Anoya en otro dispositivo';

  @override
  String get ruleSetExportQrTooLarge =>
      'Demasiado grande para un código QR: compártelo como archivo';

  @override
  String get ruleSetQrHint =>
      'En Anoya en el otro dispositivo: Conjuntos de reglas → Importar → Escanear un código QR.';

  @override
  String get startScanQr => 'Escanear un código QR';

  @override
  String get qrHint => 'Apunta la cámara a un código QR';

  @override
  String get qrHintDetail =>
      'Un enlace, una suscripción o una clave de suscripción';

  @override
  String qrParts(int received, int total) {
    return 'Clave de suscripción · parte $received de $total: mantén la cámara sobre el código';
  }

  @override
  String get qrPartsDetail => 'La aplicación muestra las partes una tras otra';

  @override
  String get qrStillLooking => 'Seguimos buscando: apunta a otro código';

  @override
  String get qrFromPhotos => 'Elegir de las fotos';

  @override
  String get qrNoCamera => 'Sin acceso a la cámara';

  @override
  String get qrNoCameraDetail =>
      'Permite el acceso a la cámara en los ajustes del sistema o elige una captura de pantalla del código QR.';

  @override
  String get qrNoCodeInImage =>
      'No se encontró ningún código QR en esta imagen';

  @override
  String get qrTorch => 'Linterna';

  @override
  String startCantUseThis(String reason) {
    return 'No se puede usar · $reason';
  }

  @override
  String get startOpenConfigFile => 'Abrir un archivo de configuración…';

  @override
  String get startOr => 'o';

  @override
  String get startSignInToServer => 'Inicia sesión en tu servidor';

  @override
  String get startOpenSubscriptionPage => 'Abrir la página de la suscripción';

  @override
  String get signInEnterServerFirst =>
      'Introduce primero la dirección del servidor';

  @override
  String get signInNoSsoProviders =>
      'Este servidor no tiene proveedores de SSO';

  @override
  String get signInNoSsoProvidersDetail =>
      'Inicia sesión con usuario y contraseña.';

  @override
  String get signInWith => 'Iniciar sesión con';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInSubtitle =>
      'El servidor de tu organización o el tuyo propio';

  @override
  String get signInServerAddress => 'Dirección del servidor';

  @override
  String get signInServerHint => 'https://tu-servidor';

  @override
  String get signInUsername => 'Usuario';

  @override
  String get signInPassword => 'Contraseña';

  @override
  String get signInWithSso => 'Iniciar sesión con SSO';

  @override
  String get uiNounItem => 'elemento';

  @override
  String get uiNounServer => 'servidor';

  @override
  String get uiNounCountry => 'país';

  @override
  String get uiRemoveFromFavorites => 'Quitar de favoritos';

  @override
  String get uiAddToFavorites => 'Añadir a favoritos';

  @override
  String get uiAllNothingMatches => 'TODOS · SIN COINCIDENCIAS';

  @override
  String uiAllMatchCount(int shown, int total) {
    return 'TODOS · $shown DE $total COINCIDEN';
  }

  @override
  String uiNoMatches(String noun, String query, int total) {
    return 'Ningún $noun coincide con «$query». Borra la búsqueda para ver los $total.';
  }

  @override
  String get ruleSetModeFullDescription =>
      'Todo el tráfico pasa por la VPN; las reglas definen excepciones.';

  @override
  String get ruleSetModeSplitDescription =>
      'Solo el tráfico que coincide con las reglas pasa por la VPN; el resto se conecta directamente.';

  @override
  String get ruleSetNoRulesSplit =>
      'Sin reglas: ningún tráfico pasa por la VPN. Añade reglas para lo que deba ir por el túnel.';

  @override
  String get ruleSetNoRulesFull =>
      'Sin reglas: todo el tráfico pasa por la VPN.';

  @override
  String get ruleSetDownload => 'Descargar';

  @override
  String get ruleKindRuleList => 'lista de reglas';

  @override
  String ruleInactiveNoDatabase(String kind) {
    return '$kind · inactiva — sin base de datos';
  }

  @override
  String ruleInactiveDesktopOnly(String kind) {
    return '$kind · inactiva — solo en escritorio';
  }

  @override
  String ruleInactiveListsOff(String kind) {
    return '$kind · inactiva — listas desactivadas';
  }

  @override
  String ruleInactiveNotDownloaded(String kind) {
    return '$kind · inactiva — no descargada';
  }

  @override
  String ruleNoResolveKind(String kind) {
    return '$kind · no-resolve';
  }

  @override
  String get ruleTypeDomainSuffix => 'dominio y subdominios';

  @override
  String get ruleTypeDomainKeyword => 'el dominio contiene';

  @override
  String get ruleTypeDomainExact => 'dominio exacto';

  @override
  String get ruleTypeIpCidr => 'rango de IP';

  @override
  String get ruleTypeProcessName => 'app por nombre';

  @override
  String get ruleTypeGeoip => 'país por IP';

  @override
  String get ruleTypeGeosite => 'listas de dominios';

  @override
  String get ruleTypeDomainRegex => 'el dominio coincide con un patrón';

  @override
  String get ruleTypeRuleList => 'una lista de tu suscripción';

  @override
  String get rulePickCountry => 'Elige un país.';

  @override
  String ruleInvalidValue(String type) {
    return 'Valor no válido para $type.';
  }

  @override
  String get ruleMatch => 'Coincidencia';

  @override
  String get ruleNotAvailableOnPlatform => 'no disponible en esta plataforma';

  @override
  String get ruleNeedsGeoDatabases => 'requiere las bases de datos geográficas';

  @override
  String get ruleAction => 'Acción';

  @override
  String get ruleActionProxyDescription => 'a través de la VPN';

  @override
  String get ruleActionDirectDescription => 'sin pasar por la VPN';

  @override
  String get ruleActionBlockDescription => 'cortar la conexión';

  @override
  String get ruleAdd => 'Añadir regla';

  @override
  String get ruleEdit => 'Editar regla';

  @override
  String get ruleCountry => 'País';

  @override
  String get ruleChoose => 'Elegir…';

  @override
  String get ruleNoResolveDescription =>
      'Coincidir solo con conexiones a IP directas, sin resolver dominios';

  @override
  String get ruleValue => 'Valor';

  @override
  String ruleSummaryGeoip(String country) {
    return 'el tráfico hacia IP de $country';
  }

  @override
  String ruleSummaryGeosite(String category) {
    return 'los dominios de «$category» (lista GeoSite)';
  }

  @override
  String ruleSummaryProcess(String name) {
    return 'el tráfico de «$name»';
  }

  @override
  String ruleSummaryMatching(String value) {
    return 'el tráfico que coincide con $value';
  }

  @override
  String get ruleSummaryProxy => 'pasa por la VPN';

  @override
  String get ruleSummaryDirect =>
      'se conecta directamente, sin pasar por la VPN';

  @override
  String get ruleSummaryBlock => 'se bloquea';

  @override
  String ruleSummary(String target, String verb) {
    return '→ $target $verb.';
  }

  @override
  String ruleSetDeleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get ruleSetDeleteBody =>
      'Las configuraciones que usan este conjunto volverán a Predeterminado.';

  @override
  String get ruleSetDeleteTooltip => 'Eliminar conjunto de reglas';

  @override
  String get ruleSetSimple => 'Sencillo';

  @override
  String get ruleSetDownloadSiteLists =>
      'Descarga primero las listas de sitios';

  @override
  String get ruleSetDownloadSiteListsDetail =>
      'Para elegir servicios hacen falta las bases de datos geográficas (~25 MB, una sola vez)';

  @override
  String ruleSetAdvancedRules(int count) {
    return 'Reglas avanzadas · $count';
  }

  @override
  String get ruleSetAdvancedRulesDetail =>
      'Se aplican antes que la lista de abajo · se editan en Avanzado';

  @override
  String get ruleSetSearchServices => 'Buscar servicios';

  @override
  String get ruleSetCountriesHeader => 'PAÍSES';

  @override
  String get ruleSetAddCountry => 'Añadir país';

  @override
  String get ruleSetServicesHeader => 'SERVICIOS';

  @override
  String get ruleSetAddCategory => 'Añadir categoría';

  @override
  String get ruleSetOtherCategoriesHeader => 'OTRAS CATEGORÍAS';

  @override
  String get ruleSetNothingSelectedSplit =>
      'Nada seleccionado · por ahora ningún tráfico pasa por la VPN';

  @override
  String get ruleSetNothingSelectedFull =>
      'Nada seleccionado · todo pasa por la VPN';

  @override
  String ruleSetSelectedSplit(int count) {
    return '$count seleccionados · todo lo demás se conecta directamente';
  }

  @override
  String ruleSetSelectedFull(int count) {
    return '$count seleccionados · se conectan directamente, el resto pasa por la VPN';
  }

  @override
  String get ruleSetOnlySelected => 'Solo los seleccionados';

  @override
  String get ruleSetAllExceptSelected => 'Todo salvo los seleccionados';

  @override
  String get ruleSetOnlySelectedDescription =>
      'Solo los servicios que elijas pasan por la VPN. Todo lo demás se conecta directamente.';

  @override
  String get ruleSetAllExceptSelectedDescription =>
      'Todo pasa por la VPN. Los servicios que elijas se conectan directamente.';

  @override
  String get ruleSetNew => 'Nuevo conjunto de reglas';

  @override
  String get ruleSetNameHint => 'Trabajo';

  @override
  String get ruleSetCreate => 'Crear';

  @override
  String ruleSetRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: '1 regla',
      zero: 'sin reglas',
    );
    return '$_temp0';
  }

  @override
  String ruleSetUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'usado por $count configuraciones',
      one: 'usado por 1 configuración',
    );
    return '$_temp0';
  }

  @override
  String ruleSetSummaryUsed(String mode, String rules, String used) {
    return '$mode · $rules · $used';
  }

  @override
  String get onDemandEnable => 'Activar bajo demanda';

  @override
  String get onDemandEnableSubtitle =>
      'El sistema aplica la primera regla que coincida';

  @override
  String get onDemandNoRules =>
      'Sin reglas. Al activar bajo demanda se añade «Conectar · Cualquier red».';

  @override
  String get onDemandRulesFootnote =>
      'Las reglas se evalúan de arriba abajo. Si ninguna coincide, el túnel se deja como está.';

  @override
  String get onDemandTagConnect => 'CONEC.';

  @override
  String get onDemandTagDisconnect => 'DESC.';

  @override
  String get onDemandTagIgnore => 'IGNORAR';

  @override
  String get onDemandNewRule => 'Nueva regla';

  @override
  String get onDemandActionIgnore => 'Ignorar';

  @override
  String get onDemandActionConnectSubtitle => 'levantar el túnel';

  @override
  String get onDemandActionDisconnectSubtitle => 'cerrar el túnel';

  @override
  String get onDemandActionIgnoreSubtitle => 'dejar el túnel como está';

  @override
  String get onDemandAny => 'Cualquiera';

  @override
  String get onDemandNameOptional => 'Nombre (opcional)';

  @override
  String get onDemandNameHint => 'Oficina';

  @override
  String get onDemandNetworkHeader => 'RED';

  @override
  String get onDemandNetworkHelpAny =>
      'La regla se comprueba en cualquier red: Wi-Fi, móvil o por cable.';

  @override
  String get onDemandNetworkHelpWifi =>
      'Cuando el dispositivo se une a una red Wi-Fi, el sistema comprueba las condiciones de abajo y aplica la regla.';

  @override
  String get onDemandNetworkHelpCellular =>
      'Cuando el dispositivo usa datos móviles, el sistema comprueba las condiciones de abajo y aplica la regla.';

  @override
  String get onDemandNetworkHelpEthernet =>
      'Cuando el dispositivo está en una red por cable, el sistema comprueba las condiciones de abajo y aplica la regla.';

  @override
  String get onDemandConditionsHeader => 'CONDICIONES';

  @override
  String get onDemandWifiNetworks => 'Redes Wi-Fi';

  @override
  String get onDemandWifiNetwork => 'Red Wi-Fi';

  @override
  String get onDemandNetworksUnit => 'REDES';

  @override
  String get onDemandWifiNetworksHelp =>
      'Coincide exactamente con el nombre de la red. Déjalo vacío para cualquier Wi-Fi.';

  @override
  String get onDemandDnsDomains => 'Dominios de búsqueda DNS';

  @override
  String get onDemandDnsDomain => 'Dominio de búsqueda DNS';

  @override
  String get onDemandDomainsUnit => 'DOMINIOS';

  @override
  String get onDemandDnsDomainsHelp =>
      'Coincide cuando el dominio de búsqueda de la red termina en una de las entradas.';

  @override
  String get onDemandDnsServers => 'Servidores DNS';

  @override
  String get onDemandDnsServer => 'Servidor DNS';

  @override
  String get onDemandServersUnit => 'SERVIDORES';

  @override
  String get onDemandDnsServersHelp =>
      'Coincide con los servidores DNS de la red; se permite un único comodín «*».';

  @override
  String get onDemandUrlProbeHeader => 'SONDA DE URL';

  @override
  String get onDemandUrlOptional => 'URL (opcional)';

  @override
  String get onDemandUrlProbeHelp =>
      'La regla solo coincide si esta URL devuelve 200 sin redirecciones.';

  @override
  String get onDemandNoEntries => 'SIN ENTRADAS';

  @override
  String onDemandEntriesHeader(int count, String unit) {
    return '$count $unit · BASTA CON QUE COINCIDA UNO';
  }

  @override
  String get onDemandConditionIgnored =>
      'La condición se ignora y la regla coincide con cualquier red del tipo seleccionado.';

  @override
  String get onDemandInterfaceAny => 'Cualquier red';

  @override
  String get onDemandInterfaceWifi => 'Wi-Fi';

  @override
  String get onDemandInterfaceCellular => 'Móvil';

  @override
  String get onDemandInterfaceEthernet => 'Ethernet';

  @override
  String onDemandSummarySsid(String values) {
    return 'SSID $values';
  }

  @override
  String onDemandSummaryDomain(String values) {
    return 'dominio $values';
  }

  @override
  String onDemandSummaryDns(String values) {
    return 'DNS $values';
  }

  @override
  String get onDemandSummaryProbe => 'sonda';

  @override
  String get onDemandStatusPaused => 'En pausa';

  @override
  String get onDemandStatusAwaitingFirstConnect =>
      'Activado · tras la primera conexión';

  @override
  String onDemandStatusOnRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activado · $count reglas',
      one: 'Activado · 1 regla',
    );
    return '$_temp0';
  }

  @override
  String get onDemandDefaultRuleName => 'En todas partes';

  @override
  String get statusNoConfiguration => 'Sin configuración';

  @override
  String get menuBarSwitching => 'Cambiando…';

  @override
  String profilesCouldntGetServer(String label) {
    return 'No se pudo obtener el servidor de $label';
  }

  @override
  String get profilesPreviousServerStillInUse => 'El anterior sigue en uso.';

  @override
  String get profilesCouldntSwitch => 'No se pudo cambiar';

  @override
  String get profilesCouldntSwitchDetail =>
      'El túnel mantuvo la configuración anterior. Inténtalo de nuevo o reconecta.';

  @override
  String get profilesNoConfigurationDetail =>
      'Añade un enlace o una suscripción, o inicia sesión en tu servidor.';

  @override
  String get profilesNoServers => 'Esta configuración no tiene servidores';

  @override
  String get profilesNoServersDetail =>
      'Actualízala o añade otra configuración.';

  @override
  String get profilesTunnelStopped => 'El túnel se detuvo';

  @override
  String get connectionCheckTimedOut => 'El servidor no respondió a tiempo.';

  @override
  String get connectionCheckClosed => 'El servidor cerró la conexión.';

  @override
  String get connectionCheckRefused => 'El servidor rechazó la conexión.';

  @override
  String get connectionCheckNoServer =>
      'No hay ningún servidor que probar: el túnel está ejecutando otra cosa.';

  @override
  String get connectionCheckTunnelNotRunning =>
      'El túnel no está en ejecución.';

  @override
  String get connectionCheckNothingCameBack => 'No llegó ninguna respuesta.';

  @override
  String get connectionCheckEngineDidNotAnswer => 'El motor no respondió.';

  @override
  String get errorDeviceLimitTitle => 'Límite de dispositivos alcanzado';

  @override
  String get errorDeviceLimitDetail =>
      'El límite de dispositivos de tu suscripción está completo, así que envió un marcador en lugar de tus servidores. Libera una plaza en tu suscripción y luego actualiza.';

  @override
  String get errorUnreadableSubscriptionTitle =>
      'No se pudo leer esta suscripción';

  @override
  String get errorUnreadableSubscriptionDetail =>
      'Tu suscripción envió un formato que esta app no reconoce. Lee listas de enlaces en base64, Clash / mihomo, Xray JSON y sing-box. No se añadió nada.';

  @override
  String get errorEmptySubscriptionTitle =>
      'Esta suscripción no tiene servidores';

  @override
  String errorEmptySubscriptionDetail(String what) {
    return 'Tu suscripción respondió con $what que no incluye ninguno. Normalmente significa que la cuenta se quedó sin días o que su límite de dispositivos está completo: pregúntales.';
  }

  @override
  String errorNoRunnableServersTitle(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Ninguno de los $total servidores puede ejecutarse aquí',
      one: 'El único servidor no puede ejecutarse aquí',
    );
    return '$_temp0';
  }

  @override
  String errorNoRunnableServersDetail(String kinds) {
    return 'Usan $kinds, que esta app aún no puede ejecutar. No se añadió nada.';
  }

  @override
  String get errorProviderMessageTitle => 'Tu suscripción envió un mensaje';

  @override
  String errorProviderMessageDetail(String lines) {
    return '$lines\n\nNo son servidores: ninguna entrada apunta a ningún sitio, así que no se añadió nada.';
  }

  @override
  String get errorSubjectDefault => 'el servidor';

  @override
  String get errorServerDidNotAnswerTitle => 'El servidor no respondió';

  @override
  String errorCouldNotReachDetail(String what) {
    return 'No se pudo contactar con $what. Comprueba tu red o elige otro servidor.';
  }

  @override
  String get errorSecureConnectionTitle =>
      'No se pudo establecer una conexión segura';

  @override
  String errorCertificateRejectedDetail(String what) {
    return 'El certificado de $what fue rechazado. Si la dirección es correcta, puede que el servidor esté mal configurado.';
  }

  @override
  String errorConnectionClosedDetail(String what) {
    return 'La conexión con $what se cerró.';
  }

  @override
  String get errorWrongCredentialsTitle => 'Usuario o contraseña incorrectos';

  @override
  String get errorWrongCredentialsDetail =>
      'Comprueba ambos e inténtalo de nuevo.';

  @override
  String get errorSessionExpiredTitle => 'Sesión caducada';

  @override
  String errorSessionExpiredDetail(String what) {
    return 'Inicia sesión de nuevo en $what.';
  }

  @override
  String get errorAccessBlockedTitle => 'Acceso bloqueado';

  @override
  String get errorAccessBlockedDetail => 'El servidor rechazó esta cuenta.';

  @override
  String get errorNothingAtAddressTitle => 'No hay nada en esta dirección';

  @override
  String errorNothingAtAddressDetail(String what) {
    return 'Comprueba el enlace: $what no tiene ninguna configuración para esta cuenta.';
  }

  @override
  String get errorServerErrorTitle => 'El servidor devolvió un error';

  @override
  String get errorServerErrorDetail =>
      'No hay nada que arreglar de este lado: inténtalo de nuevo en unos minutos.';

  @override
  String get errorServerRefusedTitle => 'El servidor rechazó la solicitud';

  @override
  String get errorNotALinkTitle => 'Esto no parece un enlace conocido';

  @override
  String get errorNotALinkDetail =>
      'Se esperaba vless://, vmess://, trojan://, ss:// o una URL de suscripción.';

  @override
  String get errorTunnelServiceNotRunningTitle =>
      'El servicio del túnel no está en ejecución';

  @override
  String get errorTunnelServiceNotRunningDetail =>
      'Anoya lo instala como el servicio de Windows «AnoyaTunnel». Reinstala la app o inicia el servicio en Servicios, y luego conecta de nuevo.';

  @override
  String get errorTunnelServiceNotRunningDetailLinux =>
      'Anoya lo instala como el servicio systemd «anoya-tunnel». Reinstala el paquete o ejecuta «sudo systemctl start anoya-tunnel», y luego conecta de nuevo.';

  @override
  String get errorTunnelServiceStoppedTitle =>
      'El servicio del túnel se detuvo';

  @override
  String get errorTunnelServiceStoppedDetail =>
      'Se reinicia solo en unos segundos: conecta de nuevo. Si se repite, el registro del túnel en Ajustes → Registros indica el motivo.';

  @override
  String get errorSystemRefusedTunnelTitle =>
      'El sistema no permitió iniciar el túnel';

  @override
  String get errorSystemRefusedTunnelDetail =>
      'Permite el perfil de VPN en los ajustes del sistema y luego conecta de nuevo.';

  @override
  String get errorSignInNotFinishedTitle => 'El inicio de sesión no terminó';

  @override
  String get errorSignInNotFinishedDetail =>
      'La ventana del navegador se cerró o el proveedor lo rechazó.';

  @override
  String get errorSomethingWentWrongTitle => 'Algo salió mal';

  @override
  String get errorSomethingWentWrongDetail =>
      'Los detalles están en Ajustes → Registros.';

  @override
  String get errorDeviceNotAcceptedTitle =>
      'Tu suscripción no aceptó este dispositivo';

  @override
  String get errorDeviceNotAcceptedDetail =>
      'Requiere un ID de dispositivo que esta app sí envió. Consulta con el soporte de tu suscripción.';

  @override
  String errorApiTimeout(String baseUrl) {
    return 'Sin respuesta de $baseUrl: comprueba la dirección y la red.';
  }

  @override
  String errorApiNetwork(String baseUrl) {
    return 'No se puede contactar con $baseUrl: comprueba la dirección y el puerto, y que el servidor esté en marcha.';
  }

  @override
  String errorApiTls(String baseUrl) {
    return 'Error de TLS al comunicarse con $baseUrl. Si el servidor usa HTTP sin cifrar, introduce la dirección con «http://».';
  }

  @override
  String errorApiRequest(String baseUrl) {
    return 'La solicitud a $baseUrl no pudo completarse: comprueba la dirección e inténtalo de nuevo.';
  }

  @override
  String get accountExpiredDetail =>
      'Renuévala en tu cuenta y luego conecta de nuevo.';

  @override
  String get accountLimitedTitle => 'Límite de tráfico alcanzado';

  @override
  String get accountLimitedDetail =>
      'El plan está agotado hasta que se renueve.';

  @override
  String get accountDeactivatedTitle => 'Acceso desactivado';

  @override
  String get accountDeactivatedDetail =>
      'El administrador desactivó esta cuenta.';

  @override
  String get accountOnHoldTitle => 'Suscripción no iniciada';

  @override
  String get accountOnHoldDetail =>
      'Empieza con la primera conexión: inténtalo de nuevo en un momento.';

  @override
  String accountOtherStateTitle(String state) {
    return 'La cuenta está $state';
  }

  @override
  String get accountOtherStateDetail =>
      'No se permite conectar en este estado.';

  @override
  String get amneziaErrorEmptyAnswerTitle => 'La pasarela no envió nada';

  @override
  String get amneziaErrorEmptyAnswerDetail =>
      'Respondió sin una configuración. Inténtalo de nuevo; si se repite, el soporte de esta suscripción tendrá que revisarlo.';

  @override
  String get amneziaErrorCancelledTitle => 'Tardó demasiado';

  @override
  String get amneziaErrorCancelledDetail =>
      'La pasarela no respondió a tiempo. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get amneziaErrorNetworkTitle => 'No se pudo contactar con la pasarela';

  @override
  String get amneziaErrorNetworkDetail =>
      'La pasarela no respondió. Suele ser la red, no la suscripción: inténtalo de nuevo en un momento.';

  @override
  String get amneziaErrorTimeoutTitle => 'La pasarela no respondió a tiempo';

  @override
  String get amneziaErrorTimeoutDetail =>
      'Sin respuesta en el tiempo permitido. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get amneziaErrorSslTitle => 'La conexión no es de confianza';

  @override
  String get amneziaErrorSslDetail =>
      'Algo interfirió con la conexión segura a la pasarela.';

  @override
  String get amneziaErrorConfigTitle =>
      'Esta compilación no puede comunicarse con la pasarela';

  @override
  String get amneziaErrorConfigDetail =>
      'Se compiló sin las credenciales de la pasarela, así que las suscripciones de este tipo no están disponibles en ella.';

  @override
  String get amneziaErrorDecryptTitle => 'No se pudo leer la respuesta';

  @override
  String get amneziaErrorDecryptDetail =>
      'La respuesta no era la que debía enviar la pasarela; a menudo se trata de una red que intercepta el tráfico.';

  @override
  String get amneziaErrorInvalidArgumentTitle =>
      'La solicitud a la pasarela era incorrecta';

  @override
  String get amneziaErrorInvalidArgumentDetail =>
      'Un defecto de esta app, no de la suscripción. Reiniciar la app ayuda; si se repite, el registro en Ajustes → Registros es lo que necesita el soporte.';

  @override
  String get amneziaErrorRefusedTitle => 'La pasarela rechazó la solicitud';

  @override
  String amneziaErrorRefusedCodeDetail(int code) {
    return 'La pasarela respondió con el código $code.';
  }

  @override
  String amneziaErrorRefusedHttpDetail(int status) {
    return 'La pasarela respondió con HTTP $status.';
  }

  @override
  String get amneziaErrorTooManyRequestsTitle => 'Demasiadas solicitudes';

  @override
  String get amneziaErrorTooManyRequestsDetail =>
      'La pasarela está limitando esta suscripción. Espera unos minutos antes de volver a intentarlo.';

  @override
  String get amneziaErrorTrialUsedTitle => 'Prueba ya utilizada';

  @override
  String get amneziaErrorTrialUsedDetail =>
      'Esta dirección ya activó una prueba.';

  @override
  String get amneziaErrorDeviceLimitDetail =>
      'Esta suscripción ya está instalada en todos los dispositivos que permite. Quita uno de la suscripción e inténtalo de nuevo.';

  @override
  String get amneziaErrorNotFoundTitle => 'Suscripción no encontrada';

  @override
  String get amneziaErrorNotFoundDetail =>
      'La pasarela no reconoce esta clave. Comprueba que se pegó completa.';

  @override
  String get amneziaErrorNewerClientTitle =>
      'La pasarela requiere un cliente más reciente';

  @override
  String get amneziaErrorNewerClientDetail =>
      'La pasarela rechazó la versión de esta app. Volverá a funcionar cuando la app se actualice.';

  @override
  String get amneziaErrorCaptchaPass =>
      'Resuélvelo en la app de la que procede esta suscripción y luego actualiza aquí.';

  @override
  String get amneziaErrorCaptchaExpiredTitle => 'El CAPTCHA caducó';

  @override
  String get amneziaErrorCaptchaRejectedTitle => 'El CAPTCHA fue rechazado';

  @override
  String get amneziaErrorCaptchaAskedTitle => 'La pasarela pidió un CAPTCHA';

  @override
  String amneziaErrorCaptchaAskedDetail(String pass) {
    return 'Esta app no puede mostrarlo. $pass';
  }

  @override
  String get amneziaErrorNotActiveTitle => 'Suscripción no activa';

  @override
  String get amneziaErrorNotActiveDetail =>
      'La pasarela no tiene ninguna suscripción activa para esta clave.';

  @override
  String get amneziaErrorLostKeyTitle => 'Esta suscripción perdió su clave';

  @override
  String get amneziaErrorLostKeyDetail =>
      'Quita la configuración y añádela de nuevo.';

  @override
  String get amneziaErrorFreeTierUnsupported =>
      'Esta suscripción es gratuita y su pasarela pide un CAPTCHA antes de emitir una configuración, algo que esta app no puede mostrar. Usa la app de la que procede o añade aquí una clave de pago.';

  @override
  String get importNotAKeyTitle => 'Esto no es una clave de suscripción';

  @override
  String get importNotAKeyDetail =>
      'Se esperaba una clave vpn:// de tu suscripción.';

  @override
  String importKeyUnsupportedTitle(String name) {
    return '$name no es compatible aquí';
  }

  @override
  String importImportedName(int count) {
    return 'Importada ($count)';
  }

  @override
  String get importFormatLinks => 'una lista de enlaces';

  @override
  String get importFormatClash => 'una suscripción Clash / mihomo';

  @override
  String get importFormatXray => 'una suscripción Xray JSON';

  @override
  String get importFormatSingbox => 'una suscripción sing-box';

  @override
  String get importFormatUnknown => 'algo no reconocido';

  @override
  String importDetectedAmneziaKey(String name) {
    return '$name · clave de suscripción';
  }

  @override
  String importDetectedServer(String type, String label) {
    return 'Servidor $type · $label';
  }

  @override
  String importDetectedSubscriptionUrl(String host) {
    return 'URL de suscripción · $host';
  }

  @override
  String importDetectedSingleServer(String label) {
    return 'Servidor · $label';
  }

  @override
  String importDetectedSubscriptionText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      one: '1 servidor',
    );
    return 'Suscripción · $_temp0';
  }

  @override
  String get importUnusableNotSubscriptionKey =>
      'No es una clave de suscripción';

  @override
  String importUnusableNotSupported(String what) {
    return '$what no es compatible';
  }

  @override
  String importUnusableTransportNotSupported(String scheme, String transport) {
    return '$scheme sobre $transport no es compatible';
  }

  @override
  String importUnusableLinkUnreadable(String scheme) {
    return 'No se puede leer el enlace $scheme://';
  }

  @override
  String get importUnusableNotALink => 'No es un enlace ni una suscripción';

  @override
  String get catalogGroupStreaming => 'STREAMING';

  @override
  String get catalogGroupMessengers => 'MENSAJERÍA';

  @override
  String get catalogGroupSocial => 'REDES SOCIALES';

  @override
  String get catalogGroupOther => 'OTROS';

  @override
  String proxyGroupUrlTest(int count) {
    return 'Menor latencia de $count';
  }

  @override
  String proxyGroupFallback(int count) {
    return 'El primero de $count que responda · en su orden';
  }

  @override
  String proxyGroupLoadBalance(int count) {
    return 'Repartido entre $count';
  }

  @override
  String proxyGroupRelay(int count) {
    return 'Cadena de $count';
  }

  @override
  String uiDoneCount(int count) {
    return 'Listo · $count';
  }

  @override
  String get ruleValuesDomains => 'Dominios';

  @override
  String get ruleValuesKeywords => 'Palabras clave';

  @override
  String get ruleValuesPatterns => 'Patrones';

  @override
  String get ruleValuesSubnets => 'Subredes';

  @override
  String get ruleValuesProcesses => 'Procesos';

  @override
  String get ruleValuesHint =>
      'Uno por línea, o separados por comas o espacios';

  @override
  String get ruleValuesHintLines => 'Uno por línea';

  @override
  String get ruleValuesPaste => 'Pegar';

  @override
  String get ruleValuesFromFile => 'Añadir desde un archivo…';

  @override
  String ruleValuesCompanion(String type) {
    return 'Se guarda como una regla $type aparte, justo después de esta';
  }

  @override
  String ruleValuesDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicados eliminados',
      one: '1 duplicado eliminado',
    );
    return '$_temp0';
  }

  @override
  String ruleValuesUnrecognized(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas no reconocidas',
      one: '1 línea no reconocida',
    );
    return '$_temp0';
  }

  @override
  String ruleValuesBadLine(int line, String reason) {
    return 'línea $line · $reason';
  }

  @override
  String get ruleValuesNotDomain => 'no es un dominio';

  @override
  String get ruleValuesNotAddress => 'no es una dirección';

  @override
  String ruleValuesNotValid(String type) {
    return 'no válido para $type';
  }

  @override
  String get ruleCountries => 'Países';

  @override
  String get ruleCategories => 'Categorías';

  @override
  String ruleSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String ruleCountDomains(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dominios',
      one: '1 dominio',
    );
    return '$_temp0';
  }

  @override
  String ruleCountKeywords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras clave',
      one: '1 palabra clave',
    );
    return '$_temp0';
  }

  @override
  String ruleCountPatterns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patrones',
      one: '1 patrón',
    );
    return '$_temp0';
  }

  @override
  String ruleCountSubnets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subredes',
      one: '1 subred',
    );
    return '$_temp0';
  }

  @override
  String ruleCountProcesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count procesos',
      one: '1 proceso',
    );
    return '$_temp0';
  }

  @override
  String ruleCountCountries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count países',
      one: '1 país',
    );
    return '$_temp0';
  }

  @override
  String ruleCountCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categorías',
      one: '1 categoría',
    );
    return '$_temp0';
  }
}
