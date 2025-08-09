#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PNG="$ROOT/assets/AppIcon.png"
ICONSET="$ROOT/assets/AppIcon.iconset"
ICNS="$ROOT/assets/AppIcon.icns"

if [ ! -f "$PNG" ]; then
  echo "AppIcon.png が見つかりません: $PNG" >&2
  exit 1
fi

rm -rf "$ICONSET" "$ICNS"
mkdir -p "$ICONSET"
# 1024基準から各サイズを作成
for size in 16 32 64 128 256 512; do
  cp "$PNG" "$ICONSET/icon_${size}x${size}.png"
  sips -Z "$size" "$ICONSET/icon_${size}x${size}.png" >/dev/null
  cp "$ICONSET/icon_${size}x${size}.png" "$ICONSET/icon_${size}x${size}@2x.png"
  sips -Z $((size*2)) "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Created $ICNS"
