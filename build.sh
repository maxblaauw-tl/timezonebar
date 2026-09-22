#!/bin/bash
# Builds TimeZoneBar.app with the Command Line Tools toolchain (no Xcode needed).
#   ./build.sh          -> build into ./TimeZoneBar.app
#   ./build.sh --run    -> build, then relaunch it
#   ./build.sh --install-> build, copy to /Applications, relaunch from there
set -euo pipefail
cd "$(dirname "$0")"

# If the selected Xcode's licence hasn't been accepted, swiftc refuses to run.
# Fall back to the Command Line Tools toolchain, which needs no licence agreement.
if ! swiftc --version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  swiftc --version >/dev/null 2>&1 || {
    echo "No usable Swift toolchain. Install Command Line Tools with: xcode-select --install" >&2
    exit 1
  }
  echo "  (using Command Line Tools toolchain)"
fi

APP_NAME="TimeZoneBar"
BUNDLE="$APP_NAME.app"
MIN_MACOS="26.0"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macos$MIN_MACOS"

echo "→ Building $APP_NAME for $TARGET"

# Assemble and sign in a temp directory. This folder lives on an iCloud-synced Desktop,
# and the file provider stamps com.apple.FinderInfo onto the bundle as soon as it appears —
# which codesign refuses to sign around, and which xattr -c can't strip. Staging elsewhere
# keeps the bundle clean until it's signed.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
STAGED="$STAGE/$BUNDLE"

mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources" "$STAGED/Contents/Frameworks"

cp Info.plist "$STAGED/Contents/Info.plist"
printf 'APPL????' > "$STAGED/Contents/PkgInfo"

cp -R Vendor/Sparkle.framework "$STAGED/Contents/Frameworks/Sparkle.framework"

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$STAGED/Contents/Resources/AppIcon.icns"
else
  echo "  ⚠ Resources/AppIcon.icns missing — run ./makeicon.sh (building without an icon)"
fi

swiftc \
  -O -whole-module-optimization \
  -parse-as-library \
  -target "$TARGET" \
  -framework SwiftUI -framework AppKit -framework ServiceManagement \
  -F Vendor -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -module-name "$APP_NAME" \
  Sources/TimeZoneBar/*.swift \
  -o "$STAGED/Contents/MacOS/$APP_NAME"

xattr -cr "$STAGED" 2>/dev/null || true

# Ad-hoc signature keeps macOS happy and gives the app a stable identity
# (needed for its preferences and the "Open at login" toggle). Sign nested
# components bottom-up so the outer app's signature can enclose them.
find "$STAGED/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" -maxdepth 1 -name '*.xpc' -exec \
  codesign --force --sign - --timestamp=none {} \;
codesign --force --sign - --timestamp=none "$STAGED/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - --timestamp=none "$STAGED/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - --timestamp=none "$STAGED/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --identifier com.maxblaauw.timezonebar --timestamp=none "$STAGED" 2>&1 \
  | grep -v 'replacing existing signature' || true

if codesign --verify "$STAGED" 2>/dev/null; then
  echo "  signed (ad-hoc)"
else
  echo "  ⚠ unsigned — the app still runs, but 'Open at login' may not stick"
fi

pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$BUNDLE"
cp -R "$STAGED" "$BUNDLE"

echo "✓ Built $(pwd)/$BUNDLE"

case "${1:-}" in
  --run)
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.4
    open "$BUNDLE"
    echo "✓ Launched — look in the menu bar"
    ;;
  --install)
    sleep 0.4
    rm -rf "/Applications/$BUNDLE"
    # Install the staged copy, not the one in this folder — /Applications isn't synced,
    # so the signature stays verifiable there.
    cp -R "$STAGED" "/Applications/$BUNDLE"
    codesign --verify "/Applications/$BUNDLE" 2>/dev/null \
      && echo "  signature verifies in /Applications" \
      || echo "  ⚠ signature does not verify in /Applications"
    open "/Applications/$BUNDLE"
    echo "✓ Installed to /Applications and launched"
    ;;
esac
