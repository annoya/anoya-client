#!/usr/bin/env bash
# Build the tunnel service for Windows or Linux; on Windows also fetch the
# Wintun driver next to it.
#
#   scripts/build-tunnel-service.sh [windows|linux] [amd64|arm64]
#
# Cross-compiles from any host: the service is pure Go (CGO_ENABLED=0; gvisor,
# which the TUN stack needs on every platform, is pure Go too). mihomo's
# Windows TUN is Wintun, which is not built here — it is a signed driver
# WireGuard LLC ships as a DLL, and the engine loads it from the directory of
# its own executable. The checksum pins the release; a different hash is a
# different file, not a newer one. On Linux the device is the kernel's tun;
# nothing to ship.
#
# Output: build/windows/service/{tunnel-service.exe,wintun.dll}, which the
# installer (windows/installer/AnnoyaTest.iss) picks up, or
# build/linux/service/tunnel-service for scripts/build-linux-deb.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

# The first argument used to be the architecture alone; a bare "amd64" still
# means Windows.
TARGET=windows
case "${1:-}" in
  windows|linux) TARGET="$1"; shift ;;
esac
ARCH="${1:-amd64}"                    # amd64 | arm64

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
# sha256sum on Linux and in Git Bash, shasum on macOS.
if command -v sha256sum >/dev/null; then
  echo "$WINTUN_SHA256  $zip" | sha256sum -c - >/dev/null
else
  echo "$WINTUN_SHA256  $zip" | shasum -a 256 -c - >/dev/null
fi
# Whatever unzipper the host has: unzip on macOS and Linux, 7z on a Windows
# runner's Git Bash, python where neither is around.
if command -v unzip >/dev/null; then
  unzip -p "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
elif command -v 7z >/dev/null; then
  7z e -so "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
else
  python3 -c "import sys,zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read(sys.argv[2]))" \
    "$zip" "wintun/bin/$ARCH/wintun.dll" > "$OUT/wintun.dll"
fi

ls -la "$OUT"
