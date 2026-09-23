#!/bin/sh
set -e
mkdir -p /var/lib/annoyatest/engine
# Every local user's app writes geo databases here; sticky so none can remove another's.
chmod 1777 /var/lib/annoyatest/engine
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl enable annoyatest-tunnel.service >/dev/null 2>&1 || true
  systemctl restart annoyatest-tunnel.service || true
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
exit 0
