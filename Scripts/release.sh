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

echo "==> 6/8 Build styled DMG (drag-to-install layout)"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Background image generated on the fly. We avoid `.background` as the folder
# name because Finder/AppleScript collides on it with the `background picture`
# property (macOS 26 error -10006); a plain "assets" folder works fine. We
# mark it hidden after population so it doesn't appear in the mounted DMG.
BG_DIR="$STAGE/assets"
mkdir -p "$BG_DIR"
swift "Scripts/make-dmg-bg.swift" "$BG_DIR/bg.png" >/dev/null

# Build a temporary read-write DMG so AppleScript can configure the Finder window.
RW_DMG="$WORK/Dubai-iqama.rw.dmg"
rm -f "$RW_DMG"
hdiutil create \
    -volname "Dubai Iqama" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$RW_DMG" >/dev/null

# Mount, then style the Finder window via AppleScript. Using "assets" instead
# of ".background" sidesteps the Finder property-name collision (error -10006).
# Styling is best-effort: even if the background fails, the icon-view layout
# (app on the left, Applications on the right) still gives a drag-to-install
# window, so we never abort the release on a Finder hiccup.
hdiutil attach "$RW_DMG" -noautoopen -nobrowse -quiet
osascript <<'OSA' || true
on run
    tell application "Finder"
        tell disk "Dubai Iqama"
            open
            delay 1
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {360, 120, 1020, 520}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 128
            try
                set background picture of theViewOptions to file "bg.png" of folder "assets"
            on error errMsg number errNum
                log "background fallback (" & errNum & "): " & errMsg
            end try
            set position of item "Dubai iqama.app" of container window to {170, 200}
            set position of item "Applications" of container window to {490, 200}
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
OSA

# Hide the assets folder so users don't see it in the mounted DMG, then
# force-detach (regular detach can fail because Finder still holds the volume).
chflags hidden "/Volumes/Dubai Iqama/assets" 2>/dev/null || true
sync
# Try clean detach a few times, then force.
for i in 1 2 3; do
    if hdiutil detach "/Volumes/Dubai Iqama" -quiet 2>/dev/null; then break; fi
    sleep 1
done
hdiutil detach "/Volumes/Dubai Iqama" -force -quiet 2>/dev/null || true

# Convert RW → compressed RO DMG (the artifact users download).
rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

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
