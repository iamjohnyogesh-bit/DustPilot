#!/bin/bash
# Builds build/DustPilot.app (ad-hoc signed, for local use). macOS 14+ with Xcode/CLT only.
#   DUSTPILOT_VERSION=1.1.0 scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(uname)" = "Darwin" ] || { echo "DustPilot builds on macOS only."; exit 1; }
VERSION="${DUSTPILOT_VERSION:-1.1.0}"
swift build -c release
APP="build/DustPilot.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DustPilot "$APP/Contents/MacOS/DustPilot"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DustPilot</string>
<key>CFBundleIdentifier</key><string>com.dustpilot.mac</string>
<key>CFBundleName</key><string>DustPilot</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION). First launch: right-click > Open (unsigned/ad-hoc)."
