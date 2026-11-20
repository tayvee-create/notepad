#!/bin/zsh
# Builds Notepad.app into ./build (and optionally runs it).
set -e
cd "$(dirname "$0")/.."
BUILD_DIR="$HOME/Library/Caches/NotepadBuild"
swift build -c release --scratch-path "$BUILD_DIR"
APP="build/Notepad.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/release/Notepad" "$APP/Contents/MacOS/Notepad"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Notepad</string>
  <key>CFBundleDisplayName</key><string>Notepad</string>
  <key>CFBundleIdentifier</key><string>wales.rowlands.notepad</string>
  <key>CFBundleExecutable</key><string>Notepad</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Text Document</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array><string>public.plain-text</string><string>public.text</string><string>public.data</string></array>
      <key>NSDocumentClass</key><string>Notepad.NotepadDocument</string>
    </dict>
  </array>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $PWD/$APP"
if [[ "$1" == "--run" ]]; then open "$APP"; fi
