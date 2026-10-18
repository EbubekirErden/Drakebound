#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Drakebound.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache -target arm64-apple-macosx14.0 Sources/*.swift -o "$APP/Contents/MacOS/Drakebound" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
xcrun swift -module-cache-path build/module-cache scripts/icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/DrakeboundD20.icns"
cp build/AppIcon.iconset/icon_512x512@2x.png "$APP/Contents/Resources/DrakeboundD20.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Drakebound</string>
<key>CFBundleIdentifier</key><string>local.fellowship.five</string>
<key>CFBundleName</key><string>Drakebound</string>
<key>CFBundleDisplayName</key><string>Drakebound</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>DrakeboundD20.icns</string>
<key>CFBundleVersion</key><string>29</string>
<key>CFBundleShortVersionString</key><string>0.29.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
