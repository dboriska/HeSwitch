#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/HeSwitch.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building HeSwitch in release mode..."
cd "${ROOT_DIR}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/HeSwitch"

echo "==> Packaging HeSwitch.app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/HeSwitch"
chmod +x "${MACOS_DIR}/HeSwitch"

cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HeSwitch</string>
    <key>CFBundleIdentifier</key>
    <string>com.hebrew.HeSwitch</string>
    <key>CFBundleName</key>
    <string>HeSwitch</string>
    <key>CFBundleDisplayName</key>
    <string>HeSwitch</string>
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
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>HeSwitch requires Accessibility access to automatically detect and replace words typed in the wrong keyboard layout.</string>
</dict>
</plist>
EOF

SIGNING_IDENTITY="${HESWITCH_SIGNING_IDENTITY:--}"
echo "==> Signing HeSwitch.app with identity: ${SIGNING_IDENTITY}..."
codesign --force --deep --sign "${SIGNING_IDENTITY}" "${APP_DIR}"

echo "==> Packaging complete: ${APP_DIR}"
