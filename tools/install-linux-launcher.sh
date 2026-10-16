#!/bin/sh
# Gives the Linux build an icon in the application menu (LXQt, KDE, GNOME, ...).
#   tools/install-linux-launcher.sh              icon + menu entry
#   tools/install-linux-launcher.sh --icon-only  just the icon (name: tiecards), for a
#                                                menu entry you made yourself: put
#                                                Icon=tiecards in it
# Everything goes under ~/.local/share (your user only; nothing needs root).
# The window itself already carries the icon (the program sets it); this is for the
# menu, which only reads the .desktop file. Run it again after moving the project.
set -e
cd "$(dirname "$0")/.."
ROOT=$(pwd)
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
ICONDIR="$DATA/icons/hicolor/256x256/apps"
mkdir -p "$ICONDIR"
cp assets/icon/tiecards.png "$ICONDIR/tiecards.png"
echo "Icon: $ICONDIR/tiecards.png"
if [ "$1" != "--icon-only" ]; then
  [ -x build/tiecards ] || { echo "build/tiecards is missing: run ./build-linux.sh first"; exit 1; }
  mkdir -p "$DATA/applications"
  cat > "$DATA/applications/tiecards.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Tiecards
Comment=Gothic vampire Tri Peaks solitaire
Exec=$ROOT/build/tiecards
Icon=tiecards
Terminal=false
Categories=Game;CardGame;
StartupWMClass=tiecards
EOF
  echo "Menu entry: $DATA/applications/tiecards.desktop"
fi
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f "$DATA/icons/hicolor" 2>/dev/null || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
