#!/bin/sh
# Regenerates the app icons from make_icon.mjs. Needs node and resvg
# (brew install resvg).
set -e
cd "$(dirname "$0")"
tmp=$(mktemp -d)
node make_icon.mjs > "$tmp/tile.svg"
node make_icon.mjs --small > "$tmp/tile_small.svg"
node make_icon.mjs --bleed > "$tmp/bleed.svg"
node make_icon.mjs --bleed --small > "$tmp/bleed_small.svg"

mac=../../macos/Runner/Assets.xcassets/AppIcon.appiconset
for n in 16 32 64; do resvg -w $n -h $n "$tmp/tile_small.svg" "$mac/app_icon_$n.png"; done
for n in 128 256 512 1024; do resvg -w $n -h $n "$tmp/tile.svg" "$mac/app_icon_$n.png"; done

res=../../android/app/src/main/res
resvg -w 48 -h 48 "$tmp/bleed_small.svg" "$res/mipmap-mdpi/ic_launcher.png"
resvg -w 72 -h 72 "$tmp/bleed_small.svg" "$res/mipmap-hdpi/ic_launcher.png"
resvg -w 96 -h 96 "$tmp/bleed.svg" "$res/mipmap-xhdpi/ic_launcher.png"
resvg -w 144 -h 144 "$tmp/bleed.svg" "$res/mipmap-xxhdpi/ic_launcher.png"
resvg -w 192 -h 192 "$tmp/bleed.svg" "$res/mipmap-xxxhdpi/ic_launcher.png"
rm -r "$tmp"
echo "icons written"
