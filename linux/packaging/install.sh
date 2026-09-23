#!/bin/sh
# usage: sudo ./install.sh   (from the unpacked portable archive)
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }
[ -d /run/systemd/system ] || { echo "the tunnel service needs systemd" >&2; exit 1; }

# A running service holds its executable open; stop it before replacing files.
/opt/anoya/service/tunnel-service -uninstall >/dev/null 2>&1 || true

rm -rf /opt/anoya
mkdir -p /opt/anoya/service
cp -a bundle/. /opt/anoya/
install -m 0755 service/tunnel-service /opt/anoya/service/tunnel-service
install -Dm 0644 packaging/org.anoya.desktop /usr/share/applications/org.anoya.desktop
install -Dm 0644 packaging/anoya.png /usr/share/icons/hicolor/256x256/apps/anoya.png
ln -sf /opt/anoya/anoya /usr/bin/anoya

mkdir -p /var/lib/anoya/engine
# Every local user's app writes geo databases here; sticky so none can remove another's.
chmod 1777 /var/lib/anoya/engine

/opt/anoya/service/tunnel-service -install
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
echo "installed: /opt/anoya, service anoya-tunnel running"
