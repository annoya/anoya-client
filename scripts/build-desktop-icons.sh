#!/usr/bin/env bash
# Windows .ico and the Linux icon from assets/icon/. Mobile and macOS app icons
# come from `dart run flutter_launcher_icons`. Needs macOS (sips).
set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for size in 16 20 24 32 40 48 64 256; do
  sips -s format png -z "$size" "$size" assets/icon/icon.png --out "$work/app_$size.png" >/dev/null
done

pack_ico() {
  python3 -I - "$@" <<'EOF'
import struct, sys
out, pngs = sys.argv[1], sys.argv[2:]
blobs = [open(p, "rb").read() for p in pngs]
offset = 6 + 16 * len(blobs)
header = struct.pack("<HHH", 0, 1, len(blobs))
entries = b""
for blob in blobs:
    w, h = struct.unpack(">II", blob[16:24])
    entries += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32, len(blob), offset)
    offset += len(blob)
with open(out, "wb") as f:
    f.write(header + entries + b"".join(blobs))
EOF
}

res=windows/runner/resources
pack_ico "$res/app_icon.ico" "$work"/app_{16,20,24,32,40,48,64,256}.png
for frame in closed open winkL winkR; do
  pack_ico "$res/tray_$frame.ico" assets/icon/tray/tray_win_{16,24,32}_"$frame".png
done

cp "$work/app_256.png" linux/packaging/anoya.png
