#!/bin/sh
# Packs assets/cards/*.png, assets/win/*.png, assets/vampires/*.png, assets/shopkeeper/*.png, assets/specials/*.png, assets/house/*.png and assets/story/*.ini into app/cards.res (embedded in the exe as RCDATA),
# plus the program icon assets/icon/tiecards.ico (MAINICON: what Windows shows for the exe, and
# TIECARDS_ICO: the same file as data, for the window icon the program sets itself).
# Resource names are the file names in upper case, e.g. CARD_HEARTS_01, WIN_SCREEN, STORY.
set -e
cd "$(dirname "$0")"
RC=app/cards.rc
: > "$RC"
for f in assets/cards/card_*.png assets/win/*.png assets/vampires/*.png assets/shopkeeper/*.png assets/specials/*.png assets/house/*.png assets/story/*.ini; do
  n=$(basename "$f"); n=${n%.*}; n=$(echo "$n" | tr 'a-z' 'A-Z')
  echo "$n RCDATA \"../$f\"" >> "$RC"
done
echo 'MAINICON ICON "../assets/icon/tiecards.ico"' >> "$RC"
# the same icon as plain data, so the program can set its own window icon on Linux
echo 'TIECARDS_ICO RCDATA "../assets/icon/tiecards.ico"' >> "$RC"
fpcres -of res -o app/cards.res "$RC"
echo "Resources: app/cards.res ($(wc -l < "$RC") entries)"
