#!/bin/bash
set -e

echo "Building mcopy..."
swift build

echo "Creating app bundle..."
APP_DIR=".build/debug/mcopy.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/debug/mcopy" "$APP_DIR/Contents/MacOS/"
cp "mcopy/Info.plist" "$APP_DIR/Contents/"
cp "mcopy/mcopy.entitlements" "$APP_DIR/Contents/Resources/"

echo "Done! App bundle created at: $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "Or run directly:"
echo "  .build/debug/mcopy"
