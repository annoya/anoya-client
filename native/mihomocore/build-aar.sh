#!/usr/bin/env bash
# Build the mihomo Go core as an Android AAR (gomobile bind) for the
# VpnService to load. Kotlin sees it as the `mobile` package: Mobile.start(fd,
# config), Mobile.setSocketProtector(...), etc.
#
# API floor 24 matches the Flutter app's minSdk. with_gvisor for the same
# reason as Apple: the userspace TUN stack needs no privileged binds.
set -euo pipefail
cd "$(dirname "$0")"

export GOWORK=off
ANDROID_API="${ANDROID_API:-24}"

# Pin the upstream gomobile/gobind into the build dir instead of trusting
# whatever fork happens to be on PATH (a sagernet gomobile expects its own
# bind package in go.mod and fails the build).
TOOLS="$(pwd)/build/tools"
if [ ! -x "$TOOLS/gomobile" ] || [ ! -x "$TOOLS/gobind" ]; then
  echo ">> installing gomobile/gobind into build/tools"
  # GOARCH pinned to the host: a global `go env -w GOARCH=...` would turn
  # this into a cross-compile, which `go install` with GOBIN refuses.
  GOBIN="$TOOLS" GOARCH="$(go env GOHOSTARCH)" go install \
    golang.org/x/mobile/cmd/gomobile@latest golang.org/x/mobile/cmd/gobind@latest
fi
export PATH="$TOOLS:$PATH"

# gomobile needs to know where the SDK/NDK live.
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

OUT=../../android/app/libs
mkdir -p "$OUT"

echo ">> gomobile bind (android/arm64, android/amd64, api $ANDROID_API)"
# cmfa: mihomo's own "running inside an Android app" tag. Without it the TUN
# listener starts a package manager that reads /data/system/packages.xml —
# system-only, so the listener dies on the first start. -s -w: the debug
# tables are a third of the binary and nothing on a phone reads them.
"$TOOLS/gomobile" bind -target=android/arm64,android/amd64 -androidapi "$ANDROID_API" \
  -tags with_gvisor,cmfa -trimpath -ldflags="-s -w" -o "$OUT/mihomocore.aar" ./mobile

echo ">> done: $OUT/mihomocore.aar"
