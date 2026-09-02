/// What this build is, in the words support asks for.
///
/// The version lives in `pubspec.yaml` and nowhere else. Every platform
/// already derives it from there (Xcode through FLUTTER_BUILD_NAME /
/// FLUTTER_BUILD_NUMBER, Gradle through flutter.versionName /
/// flutter.versionCode), and the app reads the same file, shipped as an asset,
/// at startup. It used to be copied into two Dart constants with a test to keep
/// the copy honest; one bump in one place is better than two and a guard.
///
/// The engine pin and the app's name are still stated here — they belong to
/// `go.mod` and the Xcode config, which no asset can carry — and
/// `test/app_version_test.dart` keeps those two in step.
library;

import 'package:flutter/services.dart' show rootBundle;

import 'log.dart';

/// The name shown in the app and sent as the User-Agent. Matches the bundle's
/// own name (`PRODUCT_NAME` / `CFBundleName`).
const kAppName = 'AnnoyaTest';

String _version = '';
String _build = '';

/// `version:` before the `+`. Empty until [loadAppVersion] has run.
String get appVersion => _version;

/// The build number — `version:` after the `+`, and what App Store Connect
/// counts uploads by.
String get appBuild => _build;

/// Reads the version out of the pubspec the app ships with.
///
/// Called once from `main()`, before the first frame: the About screen and the
/// User-Agent both want it, and neither can wait on a future. A regex, not the
/// YAML parser — `version:` is one line whose shape pub itself enforces, and
/// reading it must not depend on the rest of the document staying simple.
///
/// A failure is logged and left at that. An app that will not start because it
/// could not read its own version number would be a worse bug than the one it
/// is reporting.
Future<void> loadAppVersion() async {
  try {
    final text = await rootBundle.loadString('pubspec.yaml');
    final m = RegExp(r'^version:\s*(\S+?)\+(\S+)\s*$', multiLine: true).firstMatch(text);
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

/// The engine we are pinned to, from `native/mihomocore/go.mod`.
///
/// Ours to state rather than the engine's to report: mihomo ships
/// `constant.Version = "1.10.0"` in its source and only replaces it at release
/// build time, so asking the running engine would show a version that has
/// nothing to do with the commit we build against.
const kEnginePin = 'v1.19.30';

/// The engine line for the About section. A release tag reads as a version; a
/// pseudo-version (a tag, a date and a commit) is shortened to the version and
/// the commit, which are the two halves anyone acts on.
String get engineVersionLabel {
  final parts = kEnginePin.split('-');
  final version = parts.first.replaceFirst('v', '');
  return parts.length >= 3 ? 'mihomo $version-${parts.last}' : 'mihomo $version';
}

/// "1.1.0 (11)" — the pairing every Apple platform shows. Says so plainly when
/// the version could not be read, rather than showing half a number.
String get appVersionLabel => _version.isEmpty ? 'unknown' : '$_version ($_build)';

/// Where the legal documents live. Empty until they are published — the About
/// section shows the rows dimmed rather than pretending they lead somewhere.
const kTermsUrl = '';
const kPrivacyUrl = '';
