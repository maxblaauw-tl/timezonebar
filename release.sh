#!/bin/bash
# Cuts a signed update release.
#   ./release.sh 1.1
# Builds the app, bumps its version, zips it, signs it with the Sparkle key
# in the keychain, and regenerates appcast.xml. Push the result, then attach
# the zip in releases/ to a GitHub Release tagged v<version>.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?Usage: ./release.sh <version, e.g. 1.1>}"
BUILD=$(( $(defaults read "$(pwd)/Info.plist" CFBundleVersion) + 1 ))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" Info.plist

./build.sh

mkdir -p releases
ZIP="releases/TimeZoneBar-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent TimeZoneBar.app "$ZIP"

./Tools/sparkle-bin/generate_appcast \
  --download-url-prefix "https://github.com/maxblaauw/timezonebar/releases/download/v$VERSION/" \
  releases
cp releases/appcast.xml appcast.xml

echo "✓ releases/$(basename "$ZIP") ready, appcast.xml updated"
echo "  Next: git commit + tag v$VERSION + push, then upload the zip to a GitHub Release for that tag."
