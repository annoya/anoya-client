#!/usr/bin/env bash
# One-command build for the Apple client + Network Extension.
#
#   ./scripts/build.sh macos [run|build] [extra flutter args...]
#   ./scripts/build.sh ios   [run|build] [extra flutter args...]
#
# It removes the two recurring manual steps:
#   1. builds MihomoCore.xcframework only when the Go core changed (so you never
#      ship a stale slice / hit "gVisor is not included");
#   2. re-applies the Flutter+extension build-phase cycle fix (idempotent), which
#      Flutter can undo whenever it migrates the Xcode project.
# Then runs flutter for the chosen platform. Defaults: platform=macos, action=run.
set -euo pipefail
cd "$(dirname "$0")/.."                 # -> client/
FLUTTER="${FLUTTER:-flutter}"

platform="${1:-macos}"; shift || true
action="${1:-run}"; case "${1:-}" in run|build) shift || true;; *) action="run";; esac
case "$platform" in macos|ios) ;; *) echo "usage: build.sh [macos|ios] [run|build]"; exit 2;; esac

CORE_DIR="native/mihomocore"
XCF="$CORE_DIR/MihomoCore.xcframework"

# --- 1. xcframework: rebuild only if missing or older than any Go source ---
needs_build=0
if [ ! -d "$XCF" ]; then
  needs_build=1
elif [ -n "$(find "$CORE_DIR" -name '*.go' -newer "$XCF" -print -quit 2>/dev/null)" ] \
  || [ "$CORE_DIR/go.mod" -nt "$XCF" ]; then
  needs_build=1
fi
# macOS builds don't need the iOS slice and vice-versa, but the script builds
# both slices; the iOS slice is skipped automatically off a Mac without the SDK.
if [ "$needs_build" = 1 ]; then
  echo ">> MihomoCore.xcframework is missing or stale — building the Go core"
  ( cd "$CORE_DIR" && ./build-xcframework.sh )
else
  echo ">> MihomoCore.xcframework up to date (skipping Go build)"
fi

# --- 2. iOS only: keep Flutter's "Thin Binary" phase last (breaks the cycle) ---
if [ "$platform" = ios ]; then
  CP="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1 || true)"
  if [ -n "$CP" ]; then
    env GEM_HOME="$CP" GEM_PATH="$CP" ruby ios/scripts/fix_build_phase_cycle.rb 2>/dev/null | grep -v Ignoring || true
  fi
fi

# --- 3. flutter ---
target=macos
[ "$platform" = ios ] && target=ios
echo ">> flutter $action ($platform)"
if [ "$action" = build ]; then
  exec "$FLUTTER" build "$target" "$@"
else
  exec "$FLUTTER" run -d "$target" "$@"
fi
