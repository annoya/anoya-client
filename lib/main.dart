import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_prefs.dart';
import 'core/app_version.dart';
import 'core/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must run before anything logs or connects, or the first connect can render
  // with logging on.
  Log.enabled = (await AppPrefsStore.load()).collectLogs;
  // After the log switch so a failure is logged; before runApp because
  // screens and subscription requests read it.
  await loadAppVersion();
  runApp(const ProviderScope(child: VpnApp()));
}
