#!/bin/sh
# Builds Kyuhachi.app into ./build; with --install, also copies it to ~/Applications
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/Kyuhachi.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Kyuhachi "$APP/Contents/MacOS/Kyuhachi"

# App icon
ICONSET=.build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/make-icon.swift .build/icon_1024.png
for s in 16 32 128 256 512; do
    sips -z $s $s .build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) .build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# UI strings are English in code; other languages live in Localization/*.lproj
cp -R Localization/*.lproj "$APP/Contents/Resources/"
# Bundled PC-98 style font (JF Dot Shinonome Mincho 16, public domain)
cp Resources/*.ttf "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Kyuhachi</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
    <key>CFBundleIdentifier</key><string>local.kyuhachi</string>
    <key>CFBundleExecutable</key><string>Kyuhachi</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$1" = "--install" ]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/Kyuhachi.app
    cp -R "$APP" ~/Applications/
    echo "Installed ~/Applications/Kyuhachi.app"
fi
