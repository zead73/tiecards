#!/bin/sh
# Builds the Linux (Qt5) version into build/tiecards
set -e
cd "$(dirname "$0")"
tools/check-version.sh
./make-resources.sh
lazbuild --ws=qt5 app/tiecards.lpi
echo "Built: build/tiecards"
