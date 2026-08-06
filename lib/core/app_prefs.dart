import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'log.dart';

/// UI languages the app ships with. Only English for now; the enum exists so
/// adding a locale is a one-line change and the picker already has a shape.
enum AppLanguage {
  en('English', Locale('en'));

  const AppLanguage(this.label, this.locale);

  final String label;
  final Locale locale;
}

/// App-level preferences: appearance, language and log collection. Kept apart
/// from routing prefs — none of these change how traffic is routed.
class AppPrefs {
  const AppPrefs({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.en,
    this.collectLogs = true,
  });

  final ThemeMode themeMode;
  final AppLanguage language;

  /// Whether the app, the tunnel and the engine write logs at all. Off means
  /// "stop writing", not "hide": what was already collected stays readable.
  final bool collectLogs;

  /// What the settings row shows under "Appearance".
  String get themeLabel => switch (themeMode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  AppPrefs copyWith({ThemeMode? themeMode, AppLanguage? language, bool? collectLogs}) =>
      AppPrefs(
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
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/app_prefs.json');
  }

  static Future<AppPrefs> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const AppPrefs();
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return const AppPrefs();
      return AppPrefs.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      Log.e('app prefs: could not load', '$e');
      return const AppPrefs();
    }
  }

  static Future<void> save(AppPrefs prefs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(prefs.toJson()));
  }
}
