#!/bin/bash
# Cuts a signed update release.
#   ./release.sh 1.1
# Builds the app, bumps its version, zips it, signs it with the Sparkle key
# in the keychain, and regenerates appcast.xml. Push the result, then upload
# the zip in releases/ as an asset on the "updates" GitHub Release (create it
# once, tagged "updates" — every version's zip is attached there).
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

# All release zips live as assets on one stable GitHub Release (tag "updates"),
# not per-version tags — so this prefix never changes and regenerating the
# appcast for a new version can't rewrite older entries' download URLs.
./Tools/sparkle-bin/generate_appcast \
  --download-url-prefix "https://github.com/maxblaauw-tl/timezonebar/releases/download/updates/" \
  --embed-release-notes \
  releases
cp releases/appcast.xml appcast.xml

echo "✓ releases/$(basename "$ZIP") ready, appcast.xml updated"
echo "  Next: git commit + tag v$VERSION + push, then upload the zip to a GitHub Release for that tag."
