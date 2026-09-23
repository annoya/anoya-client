#!/bin/sh
# Install from the portable archive, for a distribution the packages do not
# cover: the same layout the packages produce, by hand. Needs root, and
# systemd for the service. Run from the unpacked archive:
#
#   sudo ./install.sh
#
# Puts the app in /opt/annoyatest, registers the tunnel service
# (tunnel-service -install writes the unit and starts it) and creates the
# engine directory the app and the service share. ./uninstall.sh reverses it.
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }
[ -d /run/systemd/system ] || { echo "the tunnel service needs systemd" >&2; exit 1; }

# A running service holds its executable open; stop it before the files are
# replaced. Absent is fine — a first install.
/opt/annoyatest/service/tunnel-service -uninstall >/dev/null 2>&1 || true

rm -rf /opt/annoyatest
mkdir -p /opt/annoyatest/service
cp -a bundle/. /opt/annoyatest/
install -m 0755 service/tunnel-service /opt/annoyatest/service/tunnel-service
install -Dm 0644 packaging/org.annoya.test.desktop /usr/share/applications/org.annoya.test.desktop
install -Dm 0644 packaging/annoyatest.png /usr/share/icons/hicolor/256x256/apps/annoyatest.png
ln -sf /opt/annoyatest/annoyatest /usr/bin/annoyatest

mkdir -p /var/lib/annoyatest/engine
chmod 1777 /var/lib/annoyatest/engine

/opt/annoyatest/service/tunnel-service -install
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
echo "installed: /opt/annoyatest, service annoyatest-tunnel running"
