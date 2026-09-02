import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_prefs.dart';
import 'core/app_version.dart';
import 'core/log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the log switch before anything can log or connect: leaving it to the
  // prefs provider's microtask meant the first connect of a session could still
  // render a config with logging on.
  Log.enabled = (await AppPrefsStore.load()).collectLogs;
  // After the log switch, so a failure to read it is recorded; before the first
  // frame, because the About screen and every subscription request want it.
  await loadAppVersion();
  runApp(const ProviderScope(child: VpnApp()));
}
