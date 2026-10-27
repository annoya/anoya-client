#!/usr/bin/env bash
# ABIs pinned here, not via gradle abiFilters: the Flutter plugin overrides
# them. One APK per ABI plus a universal one for people who do not know theirs.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=build/app/outputs/flutter-apk
marker="$(mktemp)"

# A user --target-platform replaces ours; passing it twice breaks gradle.
targets=(--target-platform android-arm,android-arm64,android-x64)
split=(--split-per-abi)
for arg in "$@"; do
  case "$arg" in
    --target-platform*) targets=() ;;
    --split-per-abi|--no-split-per-abi) split=() ;;
  esac
done

flutter build apk --release "${targets[@]+"${targets[@]}"}" "${split[@]+"${split[@]}"}" "$@"
if [ "${#split[@]}" -gt 0 ]; then
  flutter build apk --release "${targets[@]+"${targets[@]}"}" "$@"
fi

label="$(sed -n 's/.*android:label="\([^"]*\)".*/\1/p' android/app/src/main/AndroidManifest.xml | head -1)"
version="$(awk '/^version:/ {print $2}' pubspec.yaml)"

renamed=()
for apk in "$OUT"/app*-release.apk; do
  [ -f "$apk" ] || continue
  [ "$apk" -nt "$marker" ] || continue
  abi="$(basename "$apk" | sed -e 's/^app//' -e 's/-release\.apk$//')"
  [ -n "$abi" ] || abi="-universal"
  dest="$OUT/$label-$version$abi.apk"
  mv "$apk" "$dest"
  mv "$apk.sha1" "$dest.sha1" 2>/dev/null || true
  renamed+=("$dest")
done
rm -f "$marker"

for apk in "${renamed[@]}"; do echo "APK: $apk ($(du -h "$apk" | cut -f1))"; done
