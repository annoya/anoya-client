#!/usr/bin/env bash
# Wrapper: run fix_native_asset_frameworks.rb using the xcodeproj gem bundled
# with the Homebrew CocoaPods install. Idempotent — safe to re-run. Close Xcode
# first. Only needed if Flutter migrates the project and drops the phase.
set -euo pipefail
# xcodeproj reads the pbxproj with Ruby's default external encoding; without a
# UTF-8 locale it dies on any non-ASCII byte already in the file.
export LANG="${LANG:-en_US.UTF-8}"
CP="$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1)"
if [ -z "${CP:-}" ]; then
  echo "CocoaPods libexec not found; install cocoapods or run the .rb with xcodeproj available" >&2
  exit 1
fi
exec env GEM_HOME="$CP" GEM_PATH="$CP" ruby "$(dirname "$0")/fix_native_asset_frameworks.rb"
