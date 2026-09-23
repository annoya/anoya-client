#!/bin/sh
# A stopped service is not a VPN the user can still be relying on: it goes
# down with the package, before the files it runs from are removed. On an
# upgrade postinstall starts it again.
set -e
if [ -d /run/systemd/system ]; then
  systemctl disable --now annoyatest-tunnel.service >/dev/null 2>&1 || true
fi
exit 0
