#!/bin/sh
# Cross-compiles the Windows 64-bit version into build/tiecards.exe
#
# Needs: fpc (with the win64 units, as shipped by Arch's fpc package) and lazarus.
# The system Lazarus folder is read-only, so the first run makes a private
# writable copy (~1.5 GB) in ~/.local/share/tiecards-cross. If Lazarus is later
# upgraded, delete that folder and run this script again to refresh the copy.
set -e
cd "$(dirname "$0")"
tools/check-version.sh
./make-resources.sh
T="$HOME/.local/share/tiecards-cross"
mkdir -p "$T/config"
[ -d "$T/lazarus" ] || cp -a /usr/lib/lazarus "$T/lazarus"
lazbuild --lazarusdir="$T/lazarus" --pcp="$T/config" \
  --os=win64 --cpu=x86_64 --ws=win32 app/tiecards.lpi
echo "Built: build/tiecards.exe"
