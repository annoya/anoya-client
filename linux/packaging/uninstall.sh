#!/bin/sh
# usage: sudo ./uninstall.sh [--purge]
set -e
[ "$(id -u)" = 0 ] || { echo "run as root: sudo ./uninstall.sh" >&2; exit 1; }
/opt/anoya/service/tunnel-service -uninstall || true
rm -rf /opt/anoya
rm -f /usr/bin/anoya /usr/share/applications/org.anoya.desktop \
      /usr/share/icons/hicolor/256x256/apps/anoya.png
[ "${1:-}" = --purge ] && rm -rf /var/lib/anoya
echo "removed"
