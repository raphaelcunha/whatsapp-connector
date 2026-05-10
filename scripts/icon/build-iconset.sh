#!/bin/bash
# build-iconset.sh — render master icon, generate all sizes, drop into Assets.xcassets.
set -eo pipefail

cd "$(dirname "$0")/../.."

ICON_DIR="Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
MASTER="$TMP/icon-1024.png"

echo "==> Rendering master 1024x1024…"
swift scripts/icon/render-icon.swift "$MASTER"

mkdir -p "$ICON_DIR"

gen() {
    local size="$1" name="$2"
    sips -s format png -z "$size" "$size" "$MASTER" --out "$ICON_DIR/$name" >/dev/null
    printf "  %4dpx -> %s\n" "$size" "$name"
}

echo "==> Generating sized PNGs…"
gen   16 icon_16x16.png
gen   32 icon_16x16@2x.png
gen   32 icon_32x32.png
gen   64 icon_32x32@2x.png
gen  128 icon_128x128.png
gen  256 icon_128x128@2x.png
gen  256 icon_256x256.png
gen  512 icon_256x256@2x.png
gen  512 icon_512x512.png
gen 1024 icon_512x512@2x.png

cat > "$ICON_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png",       "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",    "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",       "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",    "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",     "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",     "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",     "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cp "$MASTER" "Resources/icon-master.png"
echo "✓ Iconset ready in $ICON_DIR"
echo "✓ Master preview at Resources/icon-master.png"
