#!/usr/bin/env bash
# usage: scripts/build.sh [macos|ios] [run|build] [extra flutter args...]
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"

platform="${1:-macos}"; shift || true
action="${1:-run}"; case "${1:-}" in run|build) shift || true;; *) action="run";; esac
case "$platform" in macos|ios) ;; *) echo "usage: build.sh [macos|ios] [run|build]"; exit 2;; esac

ensure_xcframework() {
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

# Flutter's project migrations can undo the build-phase cycle fix; reapply it.
if [ "$platform" = ios ]; then
  CP="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1 || true)"
  if [ -n "$CP" ]; then
    env GEM_HOME="$CP" GEM_PATH="$CP" ruby ios/scripts/fix_build_phase_cycle.rb 2>/dev/null | grep -v Ignoring || true
  else
    echo ">> warning: CocoaPods not found under Homebrew; skipping the build-phase cycle fix" >&2
  fi
fi

target=macos
[ "$platform" = ios ] && target=ios
echo ">> flutter $action ($platform)"
if [ "$action" = build ]; then
  exec "$FLUTTER" build "$target" "$@"
else
  exec "$FLUTTER" run -d "$target" "$@"
fi
