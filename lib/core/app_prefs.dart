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
}

class AppPrefs {
  const AppPrefs({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.en,
    this.collectLogs = true,
  });

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
      (l) => l.name == (j['language'] as String? ?? 'en'),
      orElse: () => AppLanguage.en,
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
        : const AppPrefs(),
    const AppPrefs(),
  );

  static Future<void> save(AppPrefs prefs) => _store.save(prefs.toJson());
}
