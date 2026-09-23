#!/bin/sh
# Re-register on every install, as the Windows installer does: an upgrade
# replaced the executable, and a changed unit would otherwise never reach
# systemd. The engine directory is the service's (StateDirectory) — the app
# writes the geo databases into it, so every local user may add files there
# and, with the sticky bit, none can remove another's.
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
