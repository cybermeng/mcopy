#!/bin/bash
set -e

APP_NAME="mcopy"
SCHEME="mcopy"
BUILD_DIR=".build/release"
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="${APP_NAME}_temp.dmg"
VOLUME_NAME="${APP_NAME}"

echo "=== Step 1: Release Build ==="
swift build -c release 2>&1

echo ""
echo "=== Step 2: Create App Bundle ==="
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "mcopy/Info.plist" "${APP_BUNDLE}/Contents/"

echo "App bundle: ${APP_BUNDLE}"

echo ""
echo "=== Step 3: Create DMG ==="
rm -f "${DMG_NAME}" "${DMG_TEMP}" 2>/dev/null

# Create a writable DMG
hdiutil create -srcfolder "${APP_BUNDLE}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "${DMG_TEMP}"

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_NAME}"

rm -f "${DMG_TEMP}"

echo ""
echo "=== Done! ==="
echo "App:     ${APP_BUNDLE}"
echo "DMG:     ${DMG_NAME}"
echo "Size:    $(du -h "${DMG_NAME}" | cut -f1)"
