import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_prefs.dart';
import 'core/app_version.dart';
import 'core/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.enabled = (await AppPrefsStore.load()).collectLogs;
  await loadAppVersion();
  runApp(const ProviderScope(child: VpnApp()));
}
