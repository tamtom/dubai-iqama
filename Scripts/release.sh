#!/usr/bin/env bash
# Build, sign, notarize, and staple a release DMG of Dubai Iqama.
#
# Order matters: we notarize the .app (zipped) instead of the DMG because
# notarytool's DMG preflight hangs on some networks / macOS combos. Once the
# .app is stapled, we re-pack it into a new DMG and staple that too.
#
# One-time setup (stores credential in your login keychain, NOT in the repo):
#   xcrun notarytool store-credentials "DubaiIqamaNotary" \
#       --apple-id   "your-apple-id@example.com" \
#       --team-id    "W5THJP5XXD" \
#       --password   "app-specific-password-from-appleid.apple.com"
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
ZIP="$WORK/Dubai-iqama.zip"
STAGE="$WORK/stage"
DMG="$HOME/Desktop/Dubai-Iqama-${VERSION}.dmg"

trap 'echo; echo "Build artifacts: $WORK"' EXIT

echo "==> 1/7 Archive (Release, Developer ID signed, hardened runtime)"
xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -archivePath "$ARCHIVE" \
    archive >/dev/null

echo "==> 2/7 Export with Developer ID (strips get-task-allow, applies timestamp)"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath  "$EXPORT" \
    -exportOptionsPlist "Scripts/ExportOptions.plist" >/dev/null

codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 3/7 Zip the .app for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> 4/7 Notarize (this takes a few minutes — Apple scans the binary)"
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> 5/7 Staple ticket onto the .app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> 6/8 Build DMG with the stapled .app"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create \
    -volname "Dubai Iqama" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

# Sign the DMG itself so Gatekeeper accepts it as one artifact.
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "==> 7/8 Notarize the DMG (separate submission from the .app)"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> 8/8 Staple the DMG (so the ticket is on both layers)"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "==> Gatekeeper assessment"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

echo
echo "DONE: $DMG"
