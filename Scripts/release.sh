#!/usr/bin/env bash
# Build, sign, notarize, and staple a release DMG of Dubai Iqama.
#
# Prerequisite (one-time):
#   xcrun notarytool store-credentials "DubaiIqamaNotary" \
#       --apple-id   "your-apple-id@example.com" \
#       --team-id    "W5THJP5XXD" \
#       --password   "app-specific-password-from-appleid.apple.com"
#
# Run from the repo root or anywhere — it cds into the repo itself.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="Dubai iqama.xcodeproj"
SCHEME="Dubai iqama"
TEAM_ID="W5THJP5XXD"
IDENTITY="Developer ID Application: OMAR ALTAMIMI (${TEAM_ID})"
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-DubaiIqamaNotary}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "Dubai iqama/Info.plist" 2>/dev/null || echo "1.0")

WORK="$(mktemp -d -t dubai_iqama_release.XXXXXX)"
ARCHIVE="$WORK/Dubai-iqama.xcarchive"
EXPORT="$WORK/export"
APP="$EXPORT/Dubai iqama.app"
STAGE="$WORK/stage"
DMG="$HOME/Desktop/Dubai-Iqama-${VERSION}.dmg"

trap 'echo; echo "Build artifacts: $WORK"' EXIT

echo "==> 1/6 Archive (Release)"
xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive | xcbeautify 2>/dev/null || \
xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive

echo "==> 2/6 Export with Developer ID"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath  "$EXPORT" \
    -exportOptionsPlist "Scripts/ExportOptions.plist"

echo "==> 3/6 Verify signature on .app"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 4/6 Build DMG"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create \
    -volname "Dubai Iqama" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG"

# Sign the DMG itself so Gatekeeper accepts it.
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "==> 5/6 Notarize (this can take a few minutes)"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> 6/6 Staple notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "==> Gatekeeper assessment"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

echo
echo "DONE: $DMG"
