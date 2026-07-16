#!/usr/bin/env bash
# Wrapper: run setup_tunnel.rb using the xcodeproj gem bundled with the
# Homebrew CocoaPods install. Idempotent — safe to re-run. Close Xcode first.
set -euo pipefail
CP="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1)"
if [ -z "${CP:-}" ]; then
  echo "CocoaPods libexec not found; install cocoapods or run the .rb with xcodeproj available" >&2
  exit 1
fi
exec env GEM_HOME="$CP" GEM_PATH="$CP" ruby "$(dirname "$0")/setup_tunnel.rb"
