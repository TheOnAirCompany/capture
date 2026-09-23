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
#   SPARKLE_KEY_FILE        Private EdDSA key file (CI). Defaults to the key in the login keychain.
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

notarize() {
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
    else
        xcrun notarytool submit "$1" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait
    fi
}

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
[[ -n "${SPARKLE_KEY_FILE:-}" ]] && KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
"$SPARKLE_BIN/generate_appcast" "${KEY_ARGS[@]}" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --link "https://github.com/$REPO" \
    -o "$BUILD/appcast.xml" "$BUILD/appcast"

if [[ "$PUBLISH" == 1 ]]; then
    echo "==> Publishing the GitHub release"
    gh release create "v$VERSION" "$DMG" "$BUILD/appcast.xml" \
        --repo "$REPO" --title "Capture $VERSION" --generate-notes $DRAFT
fi

echo "==> Done: $DMG"
