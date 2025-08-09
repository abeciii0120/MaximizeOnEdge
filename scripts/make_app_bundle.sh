#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MaximizeOnEdge"
BUNDLE_ID="dev.tabe.maximizeonedge"
BUILD_PATH="$PROJECT_ROOT/.build/release/$APP_NAME"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"
PLIST="$CONTENTS/Info.plist"

# 1) Build
swift build -c release

# 2) Prepare bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# 3) Info.plist
cat > "$PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# 4) Copy binary
cp -f "$BUILD_PATH" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"

# 5) Copy icon if exists
if [ -f "$PROJECT_ROOT/assets/AppIcon.icns" ]; then
  cp -f "$PROJECT_ROOT/assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

# 6) Optional ad-hoc code sign (for smoother launch locally)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep -s - "$APP_BUNDLE" || true
fi

# 7) Print result
echo "Created: $APP_BUNDLE"
