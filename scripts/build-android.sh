#!/usr/bin/env bash
# Android release build, pinned to the ABIs the engine AAR actually carries
# (arm64-v8a, x86_64 — see native/mihomocore/build-aar.sh). A plain
# `flutter build apk --release` also packs armeabi-v7a: Flutter's engine is
# there, gojni is not, and on a 32-bit phone the app installs and then dies on
# first connect instead of refusing to install. gradle-side abiFilters cannot
# fix this — the Flutter plugin merges its own target list over them.
#
# One APK per ABI, not one fat file: each is half the size, and the name says
# which phone it is for — a folder of builds is otherwise a guessing game.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=build/app/outputs/flutter-apk
marker="$(mktemp)"                       # anything older than this is a leftover

# Narrowing it further is fine (one phone, one ABI); repeating the flag is not
# — Flutter would pass the ABI twice and gradle dies packing a duplicate
# libapp.so, ten megabytes of build later.
targets=(--target-platform android-arm64,android-x64)
split=(--split-per-abi)
for arg in "$@"; do
  case "$arg" in
    --target-platform*) targets=() ;;
    --split-per-abi|--no-split-per-abi) split=() ;;
  esac
done

flutter build apk --release "${targets[@]+"${targets[@]}"}" "${split[@]+"${split[@]}"}" "$@"

# Name the file after the app and the version it carries. Flutter names every
# build `app-release.apk`, so a folder of them is a folder of identical names
# and the only way to tell which is which is the timestamp — which is exactly
# what you have lost by the time someone asks "which build is on the phone?".
# The label comes from the manifest and the version from pubspec, so the file
# says what the launcher and the About screen will say.
label="$(sed -n 's/.*android:label="\([^"]*\)".*/\1/p' android/app/src/main/AndroidManifest.xml | head -1)"
version="$(awk '/^version:/ {print $2}' pubspec.yaml)"

renamed=()
for apk in "$OUT"/app*-release.apk; do
  [ -f "$apk" ] || continue
  [ "$apk" -nt "$marker" ] || continue   # from an earlier build, leave it alone
  # app-arm64-v8a-release.apk -> "-arm64-v8a"; a fat app-release.apk (built
  # with --no-split-per-abi) is named for what it is.
  abi="$(basename "$apk" | sed -e 's/^app//' -e 's/-release\.apk$//')"
  [ -n "$abi" ] || abi="-universal"
  dest="$OUT/$label-$version$abi.apk"
  mv "$apk" "$dest"
  mv "$apk.sha1" "$dest.sha1" 2>/dev/null || true
  renamed+=("$dest")
done
rm -f "$marker"

for apk in "${renamed[@]}"; do echo "APK: $apk"; done
