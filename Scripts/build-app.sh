#!/bin/bash
# Builds ActivitySnitch and assembles a signed .app bundle at .build/ActivitySnitch.app.
# Keep the bundle id and output path stable: macOS ties notification permission
# to them for ad-hoc-signed apps.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="network.noscito.ActivitySnitch"
APP=".build/ActivitySnitch.app"
VERSION="${1:-${VERSION:-1.0.0}}"

# Fall back to CommandLineTools if the Xcode license hasn't been accepted.
if ! swift --version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ActivitySnitch "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>ActivitySnitch</string>
    <key>CFBundleExecutable</key><string>ActivitySnitch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "Built $APP"
echo "Run with: open $APP"
