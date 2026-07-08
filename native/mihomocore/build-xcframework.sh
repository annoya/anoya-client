#!/usr/bin/env bash
# Build the mihomo Go core as a macOS .xcframework (static c-archive) for the
# Network Extension to link. arm64 by default; set UNIVERSAL=1 to also build
# x86_64 and produce a fat library.
set -euo pipefail
cd "$(dirname "$0")"

# Standalone module (CGO + mihomo deps), not part of the repo go.work.
export GOWORK=off

OUT=build
rm -rf "$OUT" MihomoCore.xcframework
mkdir -p "$OUT/arm64" "$OUT/headers"

echo ">> building darwin/arm64 c-archive"
# with_gvisor: include the gVisor TUN network stack (required for tun mode).
CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
  go build -tags with_gvisor -buildmode=c-archive -o "$OUT/arm64/libmihomocore.a" .
cp "$OUT/arm64/libmihomocore.h" "$OUT/headers/mihomocore.h"

# Clang module map so Swift can `import MihomoCore`.
cat > "$OUT/headers/module.modulemap" <<'MAP'
module MihomoCore {
    header "mihomocore.h"
    export *
}
MAP

LIB="$OUT/arm64/libmihomocore.a"
if [ "${UNIVERSAL:-0}" = "1" ]; then
  echo ">> building darwin/amd64 c-archive"
  mkdir -p "$OUT/amd64" "$OUT/universal"
  CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" CC="clang -arch x86_64" \
    go build -tags with_gvisor -buildmode=c-archive -o "$OUT/amd64/libmihomocore.a" .
  lipo -create "$OUT/arm64/libmihomocore.a" "$OUT/amd64/libmihomocore.a" \
    -output "$OUT/universal/libmihomocore.a"
  LIB="$OUT/universal/libmihomocore.a"
fi

echo ">> packaging MihomoCore.xcframework"
xcodebuild -create-xcframework \
  -library "$LIB" -headers "$OUT/headers" \
  -output MihomoCore.xcframework >/dev/null

echo ">> done: $(pwd)/MihomoCore.xcframework"
lipo -info "$LIB" 2>/dev/null || true
