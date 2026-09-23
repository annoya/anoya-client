#!/bin/sh
# usage: sudo ./install.sh   (from the unpacked portable archive)
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }
[ -d /run/systemd/system ] || { echo "the tunnel service needs systemd" >&2; exit 1; }

# A running service holds its executable open; stop it before replacing files.
/opt/annoyatest/service/tunnel-service -uninstall >/dev/null 2>&1 || true

rm -rf /opt/annoyatest
mkdir -p /opt/annoyatest/service
cp -a bundle/. /opt/annoyatest/
install -m 0755 service/tunnel-service /opt/annoyatest/service/tunnel-service
install -Dm 0644 packaging/org.annoya.test.desktop /usr/share/applications/org.annoya.test.desktop
install -Dm 0644 packaging/annoyatest.png /usr/share/icons/hicolor/256x256/apps/annoyatest.png
ln -sf /opt/annoyatest/annoyatest /usr/bin/annoyatest

mkdir -p /var/lib/annoyatest/engine
# Every local user's app writes geo databases here; sticky so none can remove another's.
chmod 1777 /var/lib/annoyatest/engine

/opt/annoyatest/service/tunnel-service -install
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
echo "installed: /opt/annoyatest, service annoyatest-tunnel running"
