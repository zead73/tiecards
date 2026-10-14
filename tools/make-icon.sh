#!/bin/sh
# Builds assets/icon/tiecards.ico (the Windows program icon). The big sizes are
# the picture the web version uses (web/icons/icon-512.png); the small ones
# (16, 24, 32) are a simpler drawing, a gold crescent on the card colour, so
# they stay readable on a taskbar. Needs ImageMagick, icotool (icoutils) and rsvg-convert.
# The result is committed, so only run this to change the picture.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cat > "$T/small.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect x="8" y="8" width="240" height="240" rx="52" fill="#2f0d1c" stroke="#c9a24a" stroke-width="14"/>
  <mask id="m"><rect width="256" height="256" fill="#fff"/><circle cx="148" cy="112" r="68" fill="#000"/></mask>
  <circle cx="116" cy="136" r="84" fill="#c9a24a" mask="url(#m)"/>
  <path d="M 192 52 L 202 84 L 234 94 L 202 104 L 192 136 L 182 104 L 150 94 L 182 84 Z" fill="#c9a24a"/>
</svg>
SVG
for N in 16 24 32; do
  rsvg-convert -w $N -h $N "$T/small.svg" -o "$T/s$N.png"
done
for N in 48 64 128 256; do
  magick web/icons/icon-512.png -filter Lanczos -resize ${N}x${N} "$T/s$N.png"
done
mkdir -p assets/icon
icotool -c -o assets/icon/tiecards.ico "$T/s256.png" "$T/s128.png" "$T/s64.png" "$T/s48.png" "$T/s32.png" "$T/s24.png" "$T/s16.png"
echo "Icon: assets/icon/tiecards.ico"
icotool -l assets/icon/tiecards.ico
