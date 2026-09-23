#!/bin/sh
# The engine directory holds the user's geo databases and the last config; a
# purge (dpkg) is the one request to take them too. rpm and pacman have no
# purge, and leave the directory.
set -e
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload || true
fi
if [ "$1" = purge ]; then
  rm -rf /var/lib/annoyatest
fi
exit 0
