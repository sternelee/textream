#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

DEVICE_ID="00008030-000A21391A83802E"
DEVICE_UDID="03B551C1-4405-5372-891F-F72A02716CF7"
BUNDLE_ID="dev.leeapp.textream.ios"
DERIVED_DATA="build/ios-device-signed"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/TextreamiOS.app"

echo "🧹 Cleaning previous build..."
rm -rf "$DERIVED_DATA"

echo "🔨 Building signed iOS app..."
xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination "id=$DEVICE_ID" -derivedDataPath "$DERIVED_DATA" -allowProvisioningUpdates build

echo "📦 Installing to device..."
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

echo "🚀 Attempting to launch app..."
if xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null; then
	echo "✅ App launched!"
else
	echo "⚠️  Launch failed (device may be locked). App is installed — open it manually."
fi

echo "✅ Done!"
