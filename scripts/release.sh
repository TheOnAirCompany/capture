#!/bin/bash
# Builds, signs, notarizes and publishes a release of Capture:
# Developer ID app, styled DMG, Sparkle appcast and GitHub release.
#
# Usage: scripts/release.sh 0.2.0 [--draft] [--skip-publish]
#
# Required environment:
#   TEAM_ID                 Apple Developer team ID.
# Notarization, one of:
#   NOTARY_PROFILE          A keychain profile made with `xcrun notarytool store-credentials`.
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID   An App Store Connect API key (CI).
# Sparkle signing, optional:
#   SPARKLE_KEY_FILE        Private EdDSA key file. Defaults to ~/Desktop/_BACKUP/Capture/sparkle-private-key.txt
#                           when it exists, otherwise to the key in the login keychain.
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version> [--draft] [--skip-publish]}"
shift
DRAFT=""
PUBLISH=1
for arg in "$@"; do
    case "$arg" in
        --draft) DRAFT="--draft" ;;
        --skip-publish) PUBLISH=0 ;;
    esac
done

: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
REPO="TheOnAirCompany/capture"
BUILD_NUMBER="$(git rev-list --count HEAD)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
ARCHIVE="$BUILD/Capture.xcarchive"
EXPORT="$BUILD/export"
DMG="$BUILD/Capture-$VERSION.dmg"
SPARKLE_BIN="$ROOT/build/release/SourcePackages/artifacts/sparkle/Sparkle/bin"

cd "$ROOT"
rm -rf "$BUILD"
mkdir -p "$BUILD"

notary() {
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool "$@" --keychain-profile "$NOTARY_PROFILE"
    else
        xcrun notarytool "$@" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
    fi
}

# Submits, then waits for Apple's answer. Waiting survives network drops: it retries.
notarize() {
    local id
    id="$(notary submit "$1" --output-format json | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])')"
    echo "Submitted $1 as $id"
    local status=""
    until [[ "$status" == "Accepted" || "$status" == "Invalid" || "$status" == "Rejected" ]]; do
        notary wait "$id" --timeout 30m > /dev/null 2>&1 || sleep 30
        status="$(notary info "$id" --output-format json 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin).get("status", ""))' 2>/dev/null || true)"
        echo "Notarization status: ${status:-unknown}"
    done
    if [[ "$status" != "Accepted" ]]; then
        notary log "$id" || true
        exit 1
    fi
}

echo "==> Checking translations"
python3 scripts/strings.py

echo "==> Building Capture $VERSION ($BUILD_NUMBER)"
xcodegen generate --quiet
xcodebuild archive -quiet \
    -project Capture.xcodeproj -scheme Capture -configuration Release \
    -archivePath "$ARCHIVE" -clonedSourcePackagesDirPath "$BUILD/SourcePackages" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

cp dmg/ExportOptions.plist "$BUILD/ExportOptions.plist"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$BUILD/ExportOptions.plist"
xcodebuild -exportArchive -quiet -archivePath "$ARCHIVE" -exportPath "$EXPORT" -exportOptionsPlist "$BUILD/ExportOptions.plist"

echo "==> Notarizing the app"
ditto -c -k --keepParent "$EXPORT/Capture.app" "$BUILD/Capture.zip"
notarize "$BUILD/Capture.zip"
xcrun stapler staple "$EXPORT/Capture.app"

echo "==> Building the disk image"
dmgbuild -s dmg/settings.py -D app="$EXPORT/Capture.app" "Capture" "$DMG"
codesign --sign "Developer ID Application" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> Writing the Sparkle appcast"
mkdir -p "$BUILD/appcast"
cp "$DMG" "$BUILD/appcast/"
KEY_ARGS=()
SPARKLE_KEY_FILE="${SPARKLE_KEY_FILE:-$HOME/Desktop/_BACKUP/Capture/sparkle-private-key.txt}"
[[ -f "$SPARKLE_KEY_FILE" ]] && KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
"$SPARKLE_BIN/generate_appcast" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$REPO" \
    -o "$BUILD/appcast.xml" "$BUILD/appcast"

if [[ "$PUBLISH" == 1 ]]; then
    echo "==> Publishing the GitHub release"
    # Release notes come from the matching section of CHANGELOG.md, or from the commits.
    NOTES="$(awk -v version="## $VERSION" '$0 == version { found = 1; next } /^## / { found = 0 } found' CHANGELOG.md)"
    NOTES_ARGS=(--generate-notes)
    [[ -n "${NOTES//[[:space:]]/}" ]] && NOTES_ARGS=(--notes "$NOTES")
    gh release create "v$VERSION" "$DMG" "$BUILD/appcast.xml" \
        --repo "$REPO" --title "Capture $VERSION" "${NOTES_ARGS[@]}" $DRAFT
fi

echo "==> Done: $DMG"
