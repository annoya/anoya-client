#!/usr/bin/env bash
# Build the Amnezia gateway SDK as a macOS/iOS .xcframework (static c-archive)
# for the *app* to link — not the tunnel extension. The gateway is ordinary
# HTTPS the app makes on its own behalf, and the extension has its own Go
# runtime (MihomoCore); two of them cannot share one process.
#
# Deployment floors match the app's own, which the engine already pins:
# macOS 12 (mihomo's certstore floor) and iOS 15.
set -euo pipefail
cd "$(dirname "$0")"

MACOS_MIN="${MACOS_MIN:-12.0}"
IOS_MIN="${IOS_MIN:-15.0}"

# Standalone module (CGO + the pinned upstream submodule), not part of go.work.
export GOWORK=off

if [ ! -f upstream/go.mod ]; then
  echo "!! upstream/ is empty — run: git submodule update --init --recursive" >&2
  exit 1
fi

OUT=build
rm -rf "$OUT" Libagw.xcframework
mkdir -p "$OUT"

# One header set serves every slice: the C ABI does not vary by platform.
#
# Nested under Libagw/ rather than sitting at the root of the headers payload.
# Xcode copies every linked xcframework's headers into one include directory,
# and MihomoCore already owns `include/module.modulemap` there — two at the
# same path is a hard build error ("Multiple commands produce"). A directory
# named after the module is also where Clang looks for it, so the nesting
# costs nothing.
headers() {
  local dir="$1/Libagw"
  mkdir -p "$dir"
  cp upstream/cabi/agw.h upstream/cabi/agw_types.h "$dir/"
  cat > "$dir/module.modulemap" <<'MAP'
module Libagw {
    header "agw.h"
    export *
}
MAP
}

build_slice() { # goos goarch cc outdir
  local goos="$1" goarch="$2" cc="$3" out="$4"
  mkdir -p "$out"
  CGO_ENABLED=1 GOOS="$goos" GOARCH="$goarch" CC="$cc" \
    go build -buildmode=c-archive -trimpath -ldflags="-s -w" \
      -o "$out/libagw.a" .
}

echo ">> building darwin/arm64"
build_slice darwin arm64 "clang -arch arm64 -mmacosx-version-min=$MACOS_MIN" "$OUT/mac-arm64"
LIB="$OUT/mac-arm64/libagw.a"

if [ "${UNIVERSAL:-1}" = "1" ]; then
  echo ">> building darwin/amd64"
  SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" \
    build_slice darwin amd64 "clang -arch x86_64 -mmacosx-version-min=$MACOS_MIN" "$OUT/mac-amd64"
  mkdir -p "$OUT/mac-universal"
  lipo -create "$OUT/mac-arm64/libagw.a" "$OUT/mac-amd64/libagw.a" \
    -output "$OUT/mac-universal/libagw.a"
  LIB="$OUT/mac-universal/libagw.a"
fi

headers "$OUT/headers"
XCARGS=(-library "$LIB" -headers "$OUT/headers")

if [ "${IOS:-1}" = "1" ] && xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo ">> building ios/arm64"
  IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
  SDKROOT="$IOS_SDK" build_slice ios arm64 \
    "$(xcrun --sdk iphoneos --find clang) -arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=$IOS_MIN" \
    "$OUT/ios-arm64"
  headers "$OUT/ios-headers"
  XCARGS+=(-library "$OUT/ios-arm64/libagw.a" -headers "$OUT/ios-headers")

  echo ">> building ios-simulator/arm64"
  SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  SDKROOT="$SIM_SDK" build_slice ios arm64 \
    "$(xcrun --sdk iphonesimulator --find clang) -arch arm64 -isysroot $SIM_SDK -target arm64-apple-ios$IOS_MIN-simulator" \
    "$OUT/ios-sim-arm64"
  headers "$OUT/ios-sim-headers"
  XCARGS+=(-library "$OUT/ios-sim-arm64/libagw.a" -headers "$OUT/ios-sim-headers")
else
  echo ">> skipping iOS slices (no iOS SDK or IOS=0)"
fi

echo ">> packaging Libagw.xcframework"
xcodebuild -create-xcframework "${XCARGS[@]}" -output Libagw.xcframework >/dev/null
echo ">> done: $(pwd)/Libagw.xcframework"
