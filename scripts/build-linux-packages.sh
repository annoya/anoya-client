#!/usr/bin/env bash
# Pack the Linux build: a .deb, an .rpm and an Arch package through nfpm
# (linux/packaging/nfpm.yaml), plus a portable tar.gz with install.sh for
# everything else. The Linux counterpart of the Inno Setup step.
#
#   scripts/build-linux-packages.sh [amd64|arm64]
#
# Build first: scripts/build-tunnel-service.sh linux, then
# `flutter build linux`. Version comes from pubspec, the one place it is
# written. nfpm is a single Go binary; NFPM points at one, or it is fetched
# (pinned by version and checksum) into build/.
#
# Output: build/linux/packages/
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${1:-amd64}"
case "$ARCH" in
  amd64) bundle="build/linux/x64/release/bundle"; nfpm_arch=x86_64 ;;
  arm64) bundle="build/linux/arm64/release/bundle"; nfpm_arch=arm64 ;;
  *) echo "usage: build-linux-packages.sh [amd64|arm64]" >&2; exit 2 ;;
esac
service="build/linux/service/tunnel-service"
[ -d "$bundle" ] || { echo "!! no bundle at $bundle — run flutter build linux first" >&2; exit 1; }
[ -x "$service" ] || { echo "!! no $service — run scripts/build-tunnel-service.sh linux first" >&2; exit 1; }

NFPM_VERSION="2.47.0"
# sha256 of nfpm_<version>_Linux_x86_64.tar.gz and _Darwin_arm64.tar.gz from
# the release's checksums.txt; a different hash is a different file.
declare -A NFPM_SHA256=(
  [Linux_x86_64]="0660ca602b2d2d2ae4781a06c692b3eeb9d437ffea05b831d76e41f4a3188783"
  [Darwin_arm64]="e8c9d1d9ac218eeed479375143dc46b8d51a2b8dbba8e2f9f15ecc8faa2e404b"
)

nfpm="${NFPM:-}"
if [ -z "$nfpm" ] && command -v nfpm >/dev/null; then nfpm="$(command -v nfpm)"; fi
if [ -z "$nfpm" ]; then
  host="$(uname -s)_$(uname -m)"
  sha="${NFPM_SHA256[$host]:-}"
  [ -n "$sha" ] || { echo "!! no pinned nfpm for $host; install it and set NFPM=" >&2; exit 1; }
  dir="build/nfpm-$NFPM_VERSION"; tgz="$dir/nfpm.tar.gz"
  if [ ! -x "$dir/nfpm" ]; then
    mkdir -p "$dir"
    curl -fsSL -o "$tgz" "https://github.com/goreleaser/nfpm/releases/download/v$NFPM_VERSION/nfpm_${NFPM_VERSION}_$host.tar.gz"
    if command -v sha256sum >/dev/null; then echo "$sha  $tgz" | sha256sum -c - >/dev/null
    else echo "$sha  $tgz" | shasum -a 256 -c - >/dev/null; fi
    tar -xzf "$tgz" -C "$dir" nfpm
  fi
  nfpm="$dir/nfpm"
fi

name="$(sed -n 's/^set(BINARY_NAME "\([^"]*\)").*/\1/p' linux/CMakeLists.txt | head -1)"
version="$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)"
out="build/linux/packages"
rm -rf "$out"; mkdir -p "$out"

# nfpm expands ${VERSION} and ${ARCH}, but a content path is read as-is, so
# the bundle is staged where nfpm.yaml expects it.
rm -rf build/linux/stage && mkdir -p build/linux/stage && cp -a "$bundle" build/linux/stage/bundle
export VERSION="$version" ARCH="$ARCH"
for fmt in deb rpm archlinux; do
  echo ">> $fmt"
  "$nfpm" package -f linux/packaging/nfpm.yaml -p "$fmt" -t "$out"
done

# The portable archive: the same files, laid out for install.sh.
stage="build/linux/portable/$name-$version-linux-$nfpm_arch"
rm -rf "$stage"; mkdir -p "$stage/service" "$stage/packaging"
cp -a "$bundle" "$stage/bundle"
install -m 0755 "$service" "$stage/service/tunnel-service"
cp linux/packaging/org.annoya.test.desktop linux/packaging/annoyatest.png "$stage/packaging/"
cp linux/packaging/install.sh linux/packaging/uninstall.sh "$stage/"
echo ">> tar.gz"
tar -czf "$out/$(basename "$stage").tar.gz" -C "$(dirname "$stage")" "$(basename "$stage")"

ls -la "$out"
