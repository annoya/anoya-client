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
cd "$(dirname "$0")/.."                 # -> repository root
FLUTTER="${FLUTTER:-flutter}"

platform="${1:-macos}"; shift || true
action="${1:-run}"; case "${1:-}" in run|build) shift || true;; *) action="run";; esac
case "$platform" in macos|ios) ;; *) echo "usage: build.sh [macos|ios] [run|build]"; exit 2;; esac

# --- 1. xcframeworks: rebuild only if missing or older than any Go source ---
# Both are linked by the Xcode projects and neither is committed. A fresh clone
# without MihomoCore fails to link, loudly; without Libagw it fails the same
# way, so both are checked. macOS builds don't need the iOS slice and
# vice-versa, but the scripts build every slice; iOS is skipped automatically
# off a Mac without the SDK.
ensure_xcframework() { # dir name
  local dir="$1" xcf="$1/$2"
  if [ ! -d "$xcf" ] \
    || [ -n "$(find "$dir" -name '*.go' -not -path "$dir/upstream/*" -newer "$xcf" -print -quit 2>/dev/null)" ] \
    || [ "$dir/go.mod" -nt "$xcf" ]; then
    echo ">> $2 is missing or stale — building the Go core in $dir"
    ( cd "$dir" && ./build-xcframework.sh )
  else
    echo ">> $2 up to date (skipping Go build)"
  fi
}
ensure_xcframework native/mihomocore MihomoCore.xcframework
ensure_xcframework native/libagw Libagw.xcframework

# --- 2. iOS only: keep Flutter's "Thin Binary" phase last (breaks the cycle) ---
if [ "$platform" = ios ]; then
  CP="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1 || true)"
  if [ -n "$CP" ]; then
    env GEM_HOME="$CP" GEM_PATH="$CP" ruby ios/scripts/fix_build_phase_cycle.rb 2>/dev/null | grep -v Ignoring || true
  else
    # Said out loud: skipped silently, the "Cycle inside Runner" error comes
    # back with nothing pointing at why.
    echo ">> warning: CocoaPods not found under Homebrew; skipping the build-phase cycle fix" >&2
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
