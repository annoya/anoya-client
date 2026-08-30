#!/usr/bin/env bash
# Android release build, pinned to the ABIs the engine AAR actually carries
# (arm64-v8a, x86_64 — see native/mihomocore/build-aar.sh). A plain
# `flutter build apk --release` also packs armeabi-v7a: Flutter's engine is
# there, gojni is not, and on a 32-bit phone the app installs and then dies on
# first connect instead of refusing to install. gradle-side abiFilters cannot
# fix this — the Flutter plugin merges its own target list over them.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build apk --release --target-platform android-arm64,android-x64 "$@"
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
