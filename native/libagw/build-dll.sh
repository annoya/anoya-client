#!/usr/bin/env bash
# Build the Amnezia gateway SDK as a Windows DLL for the *app* to load at
# runtime.
#
# The other two platforms link it: Apple takes the c-archive out of
# Libagw.xcframework into the app binary, Android ships libagw.so in the APK.
# Windows has nowhere to link a Go c-archive into the MSVC-built runner, so the
# library ships as a DLL next to AnnoyaTest.exe and Dart opens it by name (see
# lib/core/amnezia/agw_ffi.dart). Windows resolves a DLL from the executable's
# own directory first, so no search path has to be set up.
#
# CGO is required — cabi is a cgo package — which means a C compiler, and cgo
# supports gcc/clang only. So this DLL is built by MinGW-w64 while the app
# around it is built by MSVC, and that is fine because the two never meet at
# link time: nothing imports a .lib, Dart opens the DLL by name at runtime, and
# everything crossing the boundary is plain C (handles, `const char*`, fixed
# width integers). Memory is freed by the side that allocated it —
# `agw_result_free` / `agw_string_free` exist for exactly that — so the two C
# runtimes never share a heap. The one convention both compilers have to agree
# on is the Microsoft x64 ABI for returning `agw_result` by value, which they
# do; x86 is not built here and is where mingw and MSVC used to differ.
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-build/windows}"
export GOWORK=off                       # standalone module, not in the workspace

if [ "${GOOS:-$(go env GOOS)}" = windows ] && command -v gcc >/dev/null 2>&1; then
  CC=gcc                                # native build on Windows
elif command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  CC=x86_64-w64-mingw32-gcc             # cross build from macOS/Linux
else
  echo "!! no C compiler for windows/amd64: install MinGW-w64" >&2
  echo "   (macOS: brew install mingw-w64; Linux: apt install gcc-mingw-w64)" >&2
  exit 1
fi

mkdir -p "$OUT"
# -trimpath and -s -w as everywhere else: no DWARF and no build paths in what
# ships. The header cgo writes next to the DLL is not used by anyone — Dart
# declares the ABI itself — but go refuses to skip it.
#
# -static-libgcc keeps the compiler's own runtime inside the DLL. Without it a
# MinGW build can import libgcc_s_seh-1.dll / libwinpthread-1.dll, which exist
# on the machine that built it and nowhere else — and a DLL that will not load
# is indistinguishable, from the app, from one that was never shipped.
echo ">> building windows/amd64 c-shared (CC=$CC)"
CGO_ENABLED=1 GOOS=windows GOARCH=amd64 CC="$CC" CGO_LDFLAGS="-static-libgcc" \
  go build -buildmode=c-shared -trimpath -ldflags="-s -w" -o "$OUT/libagw.dll" .

echo ">> done: $(cd "$OUT" && pwd)/libagw.dll"
