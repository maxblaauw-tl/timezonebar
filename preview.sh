#!/bin/bash
# Dev helper: run the logic checks and render the panel to PNGs.
set -euo pipefail
cd "$(dirname "$0")"

if ! swiftc --version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

OUT="${1:-.}"
SRC=$(ls Sources/TimeZoneBar/*.swift | grep -v 'TimeZoneBarApp.swift')
swiftc -target "$(uname -m)-apple-macos26.0" \
  -framework SwiftUI -framework AppKit -framework ServiceManagement \
  $SRC Tools/main.swift -o /tmp/tzbar-preview
/tmp/tzbar-preview "$OUT"
