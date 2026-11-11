import 'package:flutter/material.dart';
import 'json_file_store.dart';

enum AppLanguage {
  en('English', Locale('en')),
  ru('Русский', Locale('ru')),
  zh('中文', Locale('zh')),
  fr('Français', Locale('fr')),
  es('Español', Locale('es'));

  const AppLanguage(this.label, this.locale);

  final String label;
  final Locale locale;

  static AppLanguage ofSystem([Locale? system]) {
    final code = (system ?? WidgetsBinding.instance.platformDispatcher.locale)
        .languageCode;
    return values.firstWhere(
      (l) => l.locale.languageCode == code,
      orElse: () => en,
    );
  }
}

class AppPrefs {
  const AppPrefs({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.en,
    this.collectLogs = true,
  });

  factory AppPrefs.initial() => AppPrefs(language: AppLanguage.ofSystem());

  final ThemeMode themeMode;
  final AppLanguage language;

  final bool collectLogs;

  AppPrefs copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? collectLogs,
  }) => AppPrefs(
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    collectLogs: collectLogs ?? this.collectLogs,
  );

  factory AppPrefs.fromJson(Map<String, dynamic> j) => AppPrefs(
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == (j['theme_mode'] as String? ?? 'system'),
      orElse: () => ThemeMode.system,
    ),
    language: AppLanguage.values.firstWhere(
      (l) => l.name == j['language'],
      orElse: AppLanguage.ofSystem,
    ),
    collectLogs: j['collect_logs'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'theme_mode': themeMode.name,
    'language': language.name,
    'collect_logs': collectLogs,
  };
}

class AppPrefsStore {
  static final _store = JsonFileStore('app_prefs.json');

  static Future<AppPrefs> load() => _store.load(
    (j) => j is Map
        ? AppPrefs.fromJson(Map<String, dynamic>.from(j))
        : AppPrefs.initial(),
    AppPrefs.initial(),
  );

  static Future<void> save(AppPrefs prefs) => _store.save(prefs.toJson());
}
