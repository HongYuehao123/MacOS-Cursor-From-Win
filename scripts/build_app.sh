#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="WinToMacCursor"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
CACHE_DIR="${ROOT_DIR}/.swift_cache"

echo "==> Building ${APP_NAME}.app..."

mkdir -p "${MACOS}" "${RESOURCES}" "${CACHE_DIR}"

# Compile Swift sources directly into app executable
echo "==> Compiling Swift sources..."
swiftc \
    -module-cache-path "${CACHE_DIR}" \
    -O \
    $(find Sources -name "*.swift") \
    -o "${MACOS}/${APP_NAME}"

# Copy AppIcon resource if available
if [ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]; then
    echo "==> Injecting AppIcon.icns..."
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
fi

# Bundle internal macOS default restoration cape (not visible in sidebar)
if [ -f "${ROOT_DIR}/Resources/DefaultMacCursor.cape" ]; then
    echo "==> Bundling DefaultMacCursor.cape (system restore asset)..."
    cp "${ROOT_DIR}/Resources/DefaultMacCursor.cape" "${RESOURCES}/DefaultMacCursor.cape"
fi

# Bundle localization resources (.lproj)
echo "==> Bundling localization resources..."
for lproj in "${ROOT_DIR}/Resources"/*.lproj; do
    if [ -d "${lproj}" ]; then
        cp -R "${lproj}" "${RESOURCES}/"
    fi
done

# Bundle default themes into app resources
mkdir -p "${RESOURCES}/DefaultThemes"
cp -R "${ROOT_DIR}/Test/Minori Cursor animation" "${RESOURCES}/DefaultThemes/"
cp -R "${ROOT_DIR}/Test/Minori Cursor static" "${RESOURCES}/DefaultThemes/"

# Generate Info.plist
echo "==> Creating Info.plist..."
cat << 'EOF' > "${CONTENTS}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh_CN</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>WinToMacCursor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.wintomaccursor.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>WinToMacCursor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.2</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc code signing
echo "==> Signing application..."
codesign -s - --force --deep "${APP_BUNDLE}" || true

echo "==> Build completed successfully!"
echo "    Application location: ${APP_BUNDLE}"
