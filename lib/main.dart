import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/android_apps.dart';
import 'core/app_prefs.dart';
import 'core/app_version.dart';
import 'core/log.dart';
import 'core/platform_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Log.e('flutter error', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e('uncaught error', error, stack);
    return true;
  };
  Log.enabled = (await AppPrefsStore.load()).collectLogs;
  final support = await getApplicationSupportDirectory();
  Log.persistTo(File('${support.path}/logs/app.log'));
  await loadAppVersion();
  await loadAndroidSdk();
  if (isTv) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  Log.i('app started · $appVersionLabel');
  runApp(const ProviderScope(child: VpnApp()));
}
