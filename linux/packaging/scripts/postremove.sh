#!/bin/sh
set -e
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
if [ "$1" = purge ]; then
  rm -rf /var/lib/anoya
fi
exit 0
