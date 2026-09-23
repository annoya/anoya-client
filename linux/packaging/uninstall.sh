#!/bin/sh
# usage: sudo ./uninstall.sh [--purge]
set -e
[ "$(id -u)" = 0 ] || { echo "run as root: sudo ./uninstall.sh" >&2; exit 1; }
/opt/annoyatest/service/tunnel-service -uninstall || true
rm -rf /opt/annoyatest
rm -f /usr/bin/annoyatest /usr/share/applications/org.annoya.test.desktop \
      /usr/share/icons/hicolor/256x256/apps/annoyatest.png
[ "${1:-}" = --purge ] && rm -rf /var/lib/annoyatest
echo "removed"
