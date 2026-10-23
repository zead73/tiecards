#!/bin/sh
# Fails if the newest heading in CHANGELOG.md is not the version in src/version.pas
# (the one place the version is written; the Windows file properties are made from
# it by make-resources.sh).
cd "$(dirname "$0")/.."
V=$(sed -n "s/^ *AppVersion = '\(.*\)';.*/\1/p" src/version.pas)
[ -n "$V" ] || { echo "check-version: no AppVersion in src/version.pas"; exit 1; }
L=$(sed -n 's/^## \([0-9][0-9.]*\).*/\1/p' CHANGELOG.md | head -1)
if [ "$L" != "$V" ]; then
  echo "check-version: CHANGELOG.md says '$L', src/version.pas says '$V'"
  echo "Write the '## $V' section in CHANGELOG.md, or fix the version with tools/set-version.sh"
  exit 1
fi
S=$(sed -n 's/.*<strong>Tiecards<\/strong> v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' site/index.html)
if [ "$S" != "$V" ]; then
  echo "check-version: site/index.html says '$S', src/version.pas says '$V' (tools/set-version.sh $V fixes it)"
  exit 1
fi
echo "version $V"
