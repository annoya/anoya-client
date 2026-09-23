#!/usr/bin/env bash
# Pack the Linux build into a .deb — the Linux counterpart of the Inno Setup
# script (windows/installer/AnnoyaTest.iss).
#
# What a package has to do here that `flutter build linux` cannot: put the
# tunnel service next to the app, register it with systemd (it runs as root —
# creating the device is the privileged act, and the app never has that
# privilege), and hand the engine's directory to the user, who downloads the
# geo databases into it while the service reads them.
#
# Build: scripts/build-tunnel-service.sh linux, then `flutter build linux`,
# then this. Version comes from pubspec, the one place it is written.
#
# Output: build/linux/deb/<name>_<version>_<arch>.deb
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${1:-amd64}"                    # dpkg names: amd64 | arm64
case "$ARCH" in
  amd64) bundle="build/linux/x64/release/bundle" ;;
  arm64) bundle="build/linux/arm64/release/bundle" ;;
  *) echo "usage: build-linux-deb.sh [amd64|arm64]" >&2; exit 2 ;;
esac
service="build/linux/service/tunnel-service"
[ -d "$bundle" ] || { echo "!! no bundle at $bundle — run flutter build linux first" >&2; exit 1; }
[ -x "$service" ] || { echo "!! no $service — run scripts/build-tunnel-service.sh linux first" >&2; exit 1; }

name="$(sed -n 's/^set(BINARY_NAME "\([^"]*\)").*/\1/p' linux/CMakeLists.txt | head -1)"
version="$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)"
root="build/linux/deb/root"
out="build/linux/deb/${name}_${version}_${ARCH}.deb"

rm -rf "$root"
mkdir -p "$root/opt/$name/service" "$root/DEBIAN" "$root/lib/systemd/system" \
         "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps" "$root/usr/bin"

cp -a "$bundle"/. "$root/opt/$name/"
install -m 0755 "$service" "$root/opt/$name/service/tunnel-service"
install -m 0644 linux/packaging/annoyatest-tunnel.service "$root/lib/systemd/system/"
install -m 0644 linux/packaging/org.annoya.test.desktop "$root/usr/share/applications/"
install -m 0644 linux/packaging/annoyatest.png "$root/usr/share/icons/hicolor/256x256/apps/$name.png"
ln -s "/opt/$name/$name" "$root/usr/bin/$name"

size="$(du -sk "$root/opt" | cut -f1)"
cat > "$root/DEBIAN/control" <<CONTROL
Package: $name
Version: $version
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: org.annoya <noreply@annoya.org>
Installed-Size: $size
Depends: libgtk-3-0, libglib2.0-0, systemd
Description: AnnoyaTest VPN client
 A VPN client with a system-wide tunnel. The tunnel is hosted by the
 annoyatest-tunnel service, which this package registers with systemd.
CONTROL

# Re-register on every install, as the Windows installer does: an upgrade
# replaced the executable, and a changed unit would otherwise never reach
# systemd. The engine directory is the service's (StateDirectory) — the app
# writes the geo databases into it, so every local user may add files there
# and, with the sticky bit, none can remove another's.
cat > "$root/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
mkdir -p /var/lib/annoyatest/engine
chmod 1777 /var/lib/annoyatest/engine
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable annoyatest-tunnel.service >/dev/null 2>&1 || true
  systemctl restart annoyatest-tunnel.service || true
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
exit 0
POSTINST

# A stopped service is not a VPN the user can still be relying on: it goes
# down with the package, before the files it runs from are removed.
cat > "$root/DEBIAN/prerm" <<'PRERM'
#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  systemctl disable --now annoyatest-tunnel.service >/dev/null 2>&1 || true
fi
exit 0
PRERM

cat > "$root/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
# The engine directory holds the user's geo databases and the last config;
# a purge is the one request to take them too.
if [ "$1" = purge ]; then
  rm -rf /var/lib/annoyatest
fi
exit 0
POSTRM
chmod 0755 "$root/DEBIAN/postinst" "$root/DEBIAN/prerm" "$root/DEBIAN/postrm"

echo ">> $out"
dpkg-deb --build --root-owner-group "$root" "$out"
ls -la "$out"
