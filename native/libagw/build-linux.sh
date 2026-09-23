#!/usr/bin/env bash
# Build the Amnezia gateway SDK as a Linux shared library for the *app* to load
# at runtime — the Linux counterpart of build-dll.sh.
#
# The app's own runner is C++/GTK with nothing to link a Go c-archive into, so
# the library ships as libagw.so in the bundle's lib/ (linux/CMakeLists.txt
# copies it there) and Dart opens it by path (lib/core/amnezia/agw_ffi.dart).
# CGO is required — cabi is a cgo package — so this is a native build on a
# Linux host with gcc or clang; cross-building from macOS would need a Linux
# toolchain, which CI does not need and a Mac rarely has.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-build/linux}"
export GOWORK=off                       # standalone module, not in the workspace

if [ ! -f upstream/go.mod ]; then
  echo "!! upstream/ is empty — run: git submodule update --init --recursive" >&2
  exit 1
fi
if [ "$(go env GOOS)" != linux ]; then
  echo "!! build-linux.sh builds natively on Linux only (this host is $(go env GOOS))" >&2
  exit 1
fi

mkdir -p "$OUT"
# -trimpath and -s -w as everywhere else: no DWARF and no build paths in what
# ships. The header cgo writes next to the library is not used by anyone —
# Dart declares the ABI itself — but go refuses to skip it.
echo ">> building linux/$(go env GOARCH) c-shared"
CGO_ENABLED=1 GOOS=linux go build -buildmode=c-shared -trimpath -ldflags="-s -w" -o "$OUT/libagw.so" .

echo ">> done: $(cd "$OUT" && pwd)/libagw.so"
