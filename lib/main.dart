import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/android_apps.dart';
import 'core/app_prefs.dart';
import 'core/app_version.dart';
import 'core/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.enabled = (await AppPrefsStore.load()).collectLogs;
  final support = await getApplicationSupportDirectory();
  Log.persistTo(File('${support.path}/logs/app.log'));
  await loadAppVersion();
  await loadAndroidSdk();
  Log.i('app started · $appVersionLabel');
  runApp(const ProviderScope(child: VpnApp()));
}
