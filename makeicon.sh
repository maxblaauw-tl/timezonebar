#!/bin/bash
# Regenerates Resources/AppIcon.icns from AppIconView in Sources/TimeZoneBar/GlobeMark.swift.
# Only needed when the artwork changes — build.sh just copies the committed .icns.
set -euo pipefail
cd "$(dirname "$0")"

if ! swiftc --version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SRC=$(ls Sources/TimeZoneBar/*.swift | grep -v 'TimeZoneBarApp.swift')
swiftc -target "$(uname -m)-apple-macos26.0" \
  -framework SwiftUI -framework AppKit -framework ServiceManagement \
  $SRC Tools/main.swift -o "$WORK/gen"

"$WORK/gen" --icon "$WORK/AppIcon.iconset"

mkdir -p Resources
iconutil --convert icns --output Resources/AppIcon.icns "$WORK/AppIcon.iconset"
cp "$WORK/AppIcon.iconset-preview.png" Resources/AppIcon-preview.png

echo "✓ Resources/AppIcon.icns  ($(du -h Resources/AppIcon.icns | cut -f1))"
echo "  preview: Resources/AppIcon-preview.png"
