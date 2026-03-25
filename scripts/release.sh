#!/bin/bash
set -e

# Zen Release Script
# Usage: ./scripts/release.sh 1.0.0
# Requires: Developer ID certificate, Sparkle EdDSA key in keychain

VERSION="${1:?Usage: ./scripts/release.sh VERSION}"
APP_NAME="Zen"
BUNDLE_ID="com.lukashammarstrom.zen"
BUILD_DIR="build/release"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"

echo "=== Building Zen v${VERSION} ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate Xcode project
echo "→ Generating Xcode project..."
xcodegen generate --spec project.yml

# Build archive
echo "→ Building archive..."
xcodebuild archive \
    -project Zen.xcodeproj \
    -scheme Zen \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    | tail -5

# Export app from archive
echo "→ Exporting app..."
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "$APP_PATH"

# Notarize
echo "→ Submitting for notarization..."
ditto -c -k --keepParent "$APP_PATH" "${BUILD_DIR}/${APP_NAME}.zip"
xcrun notarytool submit "${BUILD_DIR}/${APP_NAME}.zip" \
    --keychain-profile "notarytool" \
    --wait

# Staple
echo "→ Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Create DMG
echo "→ Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "${BUILD_DIR}/${DMG_NAME}"

# Sign the DMG
codesign --sign "Developer ID Application" "${BUILD_DIR}/${DMG_NAME}"

# Notarize DMG too
xcrun notarytool submit "${BUILD_DIR}/${DMG_NAME}" \
    --keychain-profile "notarytool" \
    --wait
xcrun stapler staple "${BUILD_DIR}/${DMG_NAME}"

# Generate Sparkle signature
echo "→ Generating Sparkle EdDSA signature..."
SPARKLE_SIGN=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*/Sparkle/*" 2>/dev/null | head -1)
if [ -n "$SPARKLE_SIGN" ]; then
    SIGNATURE=$("$SPARKLE_SIGN" "${BUILD_DIR}/${DMG_NAME}")
    echo "Sparkle signature: $SIGNATURE"
    echo ""
    echo "Add this to your appcast.xml enclosure:"
    echo "  sparkle:edSignature=\"...\" length=\"$(stat -f%z "${BUILD_DIR}/${DMG_NAME}")\""
else
    echo "⚠️  Sparkle sign_update tool not found. Run the build in Xcode first to fetch Sparkle package."
fi

echo ""
echo "=== Done! ==="
echo "DMG: ${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "Next steps:"
echo "1. Upload DMG to GitHub Releases"
echo "2. Update appcast.xml with version, signature, and download URL"
echo "3. Push appcast.xml to main branch"
