library;

import 'package:flutter/services.dart' show rootBundle;

import 'log.dart';

const kAppName = 'AnnoyaTest';

String _version = '';
String _build = '';

String get appVersion => _version;

String get appBuild => _build;

Future<void> loadAppVersion() async {
  try {
    final text = await rootBundle.loadString('pubspec.yaml');
    final m = RegExp(
      r'^version:\s*(\S+?)\+(\S+)\s*$',
      multiLine: true,
    ).firstMatch(text);
    if (m == null) {
      Log.e('app version', 'pubspec carries no version: <name>+<build> line');
      return;
    }
    _version = m.group(1)!;
    _build = m.group(2)!;
  } catch (e) {
    Log.e('app version', e);
  }
}

// Must match native/mihomocore/go.mod (test/app_version_test.dart); the
// engine's own constant.Version is a placeholder until release builds.
const kEnginePin = 'v1.19.30';

String get engineVersionLabel {
  final parts = kEnginePin.split('-');
  final version = parts.first.replaceFirst('v', '');
  return parts.length >= 3
      ? 'mihomo $version-${parts.last}'
      : 'mihomo $version';
}

String get appVersionLabel =>
    _version.isEmpty ? 'unknown' : '$_version ($_build)';

const kTermsUrl = '';
const kPrivacyUrl = '';
