#!/usr/bin/env bash
# usage: scripts/build-tunnel-service.sh [windows|linux] [amd64|arm64]
set -euo pipefail
cd "$(dirname "$0")/.."

# Backward compatible: a bare arch still means Windows.
TARGET=windows
case "${1:-}" in
  windows|linux) TARGET="$1"; shift ;;
esac
ARCH="${1:-amd64}"

if [ "$TARGET" = linux ]; then
  OUT="build/linux/service"
  mkdir -p "$OUT"
  echo ">> tunnel-service (linux/$ARCH)"
  ( cd native/mihomocore && GOWORK=off CGO_ENABLED=0 GOOS=linux GOARCH="$ARCH" \
      go build -tags with_gvisor -trimpath -ldflags "-s -w" -o "../../$OUT/tunnel-service" ./cmd/tunnel-service )
  ls -la "$OUT"
  exit 0
fi

OUT="build/windows/service"
WINTUN_VERSION="0.14.1"
WINTUN_SHA256="07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51"

mkdir -p "$OUT"

echo ">> tunnel-service.exe ($ARCH)"
( cd native/mihomocore && GOWORK=off CGO_ENABLED=0 GOOS=windows GOARCH="$ARCH" \
    go build -tags with_gvisor -trimpath -ldflags "-s -w" -o "../../$OUT/tunnel-service.exe" ./cmd/tunnel-service )

echo ">> wintun.dll ($WINTUN_VERSION, $ARCH)"
zip="build/windows/wintun-$WINTUN_VERSION.zip"
if [ ! -f "$zip" ]; then
  curl -fsSL -o "$zip" "https://www.wintun.net/builds/wintun-$WINTUN_VERSION.zip"
fi
if command -v sha256sum >/dev/null; then
  echo "$WINTUN_SHA256  $zip" | sha256sum -c - >/dev/null
else
  echo "$WINTUN_SHA256  $zip" | shasum -a 256 -c - >/dev/null
fi
if command -v unzip >/dev/null; then
  unzip -p "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
elif command -v 7z >/dev/null; then
  7z e -so "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
else
  python3 -c "import sys,zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read(sys.argv[2]))" \
    "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
fi

ls -la "$OUT"
