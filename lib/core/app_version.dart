/// What this build is, in the words support asks for.
///
/// Duplicated on purpose and guarded by a test: the app cannot read
/// `pubspec.yaml` or `go.mod` at runtime, and the alternatives — a code
/// generator, or a plugin that reads the bundle — are more machinery than three
/// strings deserve. `test/app_version_test.dart` fails when either file moves
/// without this one, so the duplication cannot rot silently.
library;

/// The name shown in the app and sent as the User-Agent. Matches the bundle's
/// own name (`PRODUCT_NAME` / `CFBundleName`).
const kAppName = 'AnnoyaTest';

/// `version:` in pubspec.yaml, before the `+`.
const kAppVersion = '1.0.0';

/// The build number — `version:` after the `+`, and what App Store Connect
/// counts uploads by.
const kAppBuild = '4';

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

/// "1.0.0 (3)" — the pairing every Apple platform shows.
String get appVersionLabel => '$kAppVersion ($kAppBuild)';

/// Where the legal documents live. Empty until they are published — the About
/// section shows the rows dimmed rather than pretending they lead somewhere.
const kTermsUrl = '';
const kPrivacyUrl = '';
