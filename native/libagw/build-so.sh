#!/usr/bin/env bash
# Build the Amnezia gateway SDK as Android shared libraries for the *app*
# process. The engine's AAR lives in the :tunnel process and carries its own Go
# runtime; this is a second, separate one in a second, separate process — which
# is the only arrangement that works, since two Go runtimes cannot share a
# process.
#
# c-shared rather than an AAR: nothing here is called from Kotlin, only from
# Dart over FFI, so a plain .so in jniLibs is the whole delivery.
set -euo pipefail
cd "$(dirname "$0")"

export GOWORK=off
ANDROID_API="${ANDROID_API:-24}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

if [ ! -f upstream/go.mod ]; then
  echo "!! upstream/ is empty — run: git submodule update --init --recursive" >&2
  exit 1
fi

NDK_DIR="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1)"
[ -n "$NDK_DIR" ] || { echo "!! no NDK under $ANDROID_HOME/ndk" >&2; exit 1; }
HOST="$(uname | tr '[:upper:]' '[:lower:]')-x86_64"
BIN="$NDK_DIR/toolchains/llvm/prebuilt/$HOST/bin"
[ -d "$BIN" ] || BIN="$NDK_DIR/toolchains/llvm/prebuilt/$(uname | tr '[:upper:]' '[:lower:]')-aarch64/bin"

OUT=../../android/app/src/main/jniLibs

# The ABIs the engine AAR also ships; anything else would install and then
# fail to find a library at runtime.
build() { # abi goarch triple
  local abi="$1" goarch="$2" triple="$3"
  echo ">> $abi"
  mkdir -p "$OUT/$abi"
  CGO_ENABLED=1 GOOS=android GOARCH="$goarch" \
    CC="$BIN/${triple}${ANDROID_API}-clang" \
    go build -buildmode=c-shared -trimpath -ldflags="-s -w" \
      -o "$OUT/$abi/libagw.so" .
}

build arm64-v8a arm64 aarch64-linux-android
build x86_64 amd64 x86_64-linux-android

echo ">> done: $(cd "$OUT" && pwd)"
ls -la "$OUT"/*/libagw.so
