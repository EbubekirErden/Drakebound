#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/products.noindex/Drakebound.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache -target arm64-apple-macosx14.0 Sources/*.swift -o "$APP/Contents/MacOS/Drakebound" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
xcrun swift -module-cache-path build/module-cache scripts/icon.swift build/AppIcon.iconset
xcrun swift -module-cache-path build/module-cache scripts/icon.swift build/SidebarMark.iconset --sidebar-mark
cp build/SidebarMark.iconset/icon_128x128@2x.png "$APP/Contents/Resources/DrakeboundSidebarMark.png"
mkdir -p "$APP/Contents/Resources/SRD"
cp Resources/SRD/* "$APP/Contents/Resources/SRD/"
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
<key>CFBundleVersion</key><string>42</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>local.fellowship.five.list-reorder</string>
<key>UTTypeDescription</key><string>Drakebound list order</string>
<key>UTTypeConformsTo</key><array><string>public.data</string></array>
</dict></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
# Development bundles should not become extra Drakebound entries in Launchpad.
DRAKEBOUND_REGISTRAR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$DRAKEBOUND_REGISTRAR" ]; then
    "$DRAKEBOUND_REGISTRAR" -u "$PWD/$APP" >/dev/null 2>&1 || true
fi
echo "Built: $APP"
