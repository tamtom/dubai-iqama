#!/usr/bin/env bash
# Build, sign, notarize, and staple a release DMG of Iqama.
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

# Version comes from the MARKETING_VERSION build setting (GENERATE_INFOPLIST_FILE
# injects it as CFBundleShortVersionString), not the hand-written Info.plist.
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')
VERSION="${VERSION:-1.0}"

WORK="$(mktemp -d -t dubai_iqama_release.XXXXXX)"
ARCHIVE="$WORK/Dubai-iqama.xcarchive"
EXPORT="$WORK/export"
APP="$EXPORT/Dubai iqama.app"
ZIP="$WORK/Dubai-iqama.zip"
STAGE="$WORK/stage"
DMG="$HOME/Desktop/Iqama-${VERSION}.dmg"

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

echo "==> 6/8 Build styled DMG (dmgbuild — dark background, drag-to-install)"
# Generate the dark background image (opaque RGB; Finder shows white labels on it).
BG_PNG="$WORK/bg.png"
swift "Scripts/make-dmg-bg.swift" "$BG_PNG" >/dev/null

# dmgbuild writes the .DS_Store directly (no flaky Finder AppleScript), so the
# background + icon layout apply reliably on macOS 26.
rm -f "$DMG"
/usr/bin/python3 -m dmgbuild \
    -s "Scripts/dmg-settings.py" \
    -D app="$APP" \
    -D bg="$BG_PNG" \
    "Iqama" \
    "$DMG"

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
