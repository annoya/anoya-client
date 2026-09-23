#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  systemctl disable --now annoyatest-tunnel.service >/dev/null 2>&1 || true
fi
exit 0
