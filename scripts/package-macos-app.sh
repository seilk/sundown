#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
APP_NAME="Sundown"
EXECUTABLE_NAME="SundownApp"
BUNDLE_ID="com.seilk.sundown"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE_DIR" "$ZIP_PATH"

swift build -c release --product "$EXECUTABLE_NAME"
BIN_PATH="$(swift build -c release --show-bin-path)"

mkdir -p "$MACOS_DIR"
cp "$BIN_PATH/$EXECUTABLE_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

if [[ -n "${APPLE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --sign "$APPLE_SIGN_IDENTITY" --options runtime --timestamp "$APP_BUNDLE_DIR"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE_DIR" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

echo "Created: $ZIP_PATH"
echo "SHA256: $SHA256"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "zip_name=$ZIP_NAME"
    echo "zip_path=$ZIP_PATH"
    echo "sha256=$SHA256"
  } >> "$GITHUB_OUTPUT"
fi
