#!/usr/bin/env bash
# Build the mihomo Go core as a macOS .xcframework (static c-archive) for the
# Network Extension to link. Universal (arm64 + x86_64) by default; set
# UNIVERSAL=0 for an arm64-only library.
#
# The macOS slices pin -mmacosx-version-min explicitly, exactly as the iOS ones
# do. Without it the c-archive inherits the host SDK's default (macOS 26 on this
# toolchain) and every link warns "object file was built for newer macOS version
# than being linked"; the archive then claims a floor the app does not have.
#
# 12.0 is not a preference, it is mihomo's real floor: its certstore dependency
# calls SecTrustCopyCertificateChain, introduced in macOS 12. Built lower, that
# call compiles with an unguarded-availability warning and is a null deref on an
# older system. Keep in step with MACOSX_DEPLOYMENT_TARGET in
# macos/Runner.xcodeproj — the app cannot claim a floor below the engine's.
set -euo pipefail
cd "$(dirname "$0")"

MACOS_MIN="${MACOS_MIN:-12.0}"

# Standalone module (CGO + mihomo deps), not part of the repo go.work.
export GOWORK=off

OUT=build
rm -rf "$OUT" MihomoCore.xcframework
mkdir -p "$OUT/arm64" "$OUT/headers"

echo ">> building darwin/arm64 c-archive"
# with_gvisor: include the gVisor TUN network stack (required for tun mode).
CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
  CC="clang -arch arm64 -mmacosx-version-min=$MACOS_MIN" \
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
if [ "${UNIVERSAL:-1}" = "1" ]; then
  echo ">> building darwin/amd64 c-archive"
  mkdir -p "$OUT/amd64" "$OUT/universal"
  CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" \
    CC="clang -arch x86_64 -mmacosx-version-min=$MACOS_MIN" \
    go build -tags with_gvisor -buildmode=c-archive -o "$OUT/amd64/libmihomocore.a" .
  lipo -create "$OUT/arm64/libmihomocore.a" "$OUT/amd64/libmihomocore.a" \
    -output "$OUT/universal/libmihomocore.a"
  LIB="$OUT/universal/libmihomocore.a"
fi

# iOS device slice (arm64), built WITH with_gvisor — same as macOS. The gVisor
# userspace TUN stack is the one that works inside the NE sandbox: it needs no
# real socket binds, whereas mihomo's `system` stack tries to bind the fake-ip
# gateway (198.18.0.1) and fails with "can't assign requested address" in the
# NE. Memory (iOS NE ~50MB cap) is validated empirically on device instead.
# Set IOS=0 to skip (e.g. on a Mac without the iOS SDK).
XCARGS=(-library "$LIB" -headers "$OUT/headers")
if [ "${IOS:-1}" = "1" ] && xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo ">> building ios/arm64 c-archive (with_gvisor)"
  mkdir -p "$OUT/ios-arm64" "$OUT/ios-headers"
  IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
  CGO_ENABLED=1 GOOS=ios GOARCH=arm64 \
    SDKROOT="$IOS_SDK" \
    CC="$(xcrun --sdk iphoneos --find clang) -arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=15.0" \
    go build -tags with_gvisor -buildmode=c-archive -o "$OUT/ios-arm64/libmihomocore.a" .
  cp "$OUT/ios-arm64/libmihomocore.h" "$OUT/ios-headers/mihomocore.h"
  cat > "$OUT/ios-headers/module.modulemap" <<'MAP'
module MihomoCore {
    header "mihomocore.h"
    export *
}
MAP
  XCARGS+=(-library "$OUT/ios-arm64/libmihomocore.a" -headers "$OUT/ios-headers")
else
  echo ">> skipping iOS slice (no iOS SDK or IOS=0)"
fi

# iOS simulator slice (arm64), so the app builds and UI can be exercised in
# the Simulator. NE tunnels don't actually run there — this is link-only.
if [ "${IOS:-1}" = "1" ] && xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  echo ">> building ios-simulator/arm64 c-archive (with_gvisor)"
  mkdir -p "$OUT/ios-sim-arm64" "$OUT/ios-sim-headers"
  SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  CGO_ENABLED=1 GOOS=ios GOARCH=arm64 \
    SDKROOT="$SIM_SDK" \
    CC="$(xcrun --sdk iphonesimulator --find clang) -arch arm64 -isysroot $SIM_SDK -target arm64-apple-ios15.0-simulator" \
    go build -tags with_gvisor -buildmode=c-archive -o "$OUT/ios-sim-arm64/libmihomocore.a" .
  cp "$OUT/ios-sim-arm64/libmihomocore.h" "$OUT/ios-sim-headers/mihomocore.h"
  cat > "$OUT/ios-sim-headers/module.modulemap" <<'MAP'
module MihomoCore {
    header "mihomocore.h"
    export *
}
MAP
  XCARGS+=(-library "$OUT/ios-sim-arm64/libmihomocore.a" -headers "$OUT/ios-sim-headers")
else
  echo ">> skipping iOS simulator slice (no simulator SDK or IOS=0)"
fi

echo ">> packaging MihomoCore.xcframework"
xcodebuild -create-xcframework "${XCARGS[@]}" \
  -output MihomoCore.xcframework >/dev/null

echo ">> done: $(pwd)/MihomoCore.xcframework"
lipo -info "$LIB" 2>/dev/null || true
