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
RELEASE_BUILD="${RELEASE_BUILD:-0}"
APPLE_NOTARY_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-${APPLE_PASSWORD:-}}"

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE_DIR" "$ZIP_PATH"

swift build -c release --product "$EXECUTABLE_NAME"
BIN_PATH="$(swift build -c release --show-bin-path)"

mkdir -p "$MACOS_DIR"
cp "$BIN_PATH/$EXECUTABLE_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
mkdir -p "$CONTENTS_DIR/Resources"

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

if [[ "$RELEASE_BUILD" == "1" ]]; then
  if [[ -z "${APPLE_SIGN_IDENTITY:-}" || -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "$APPLE_NOTARY_PASSWORD" ]]; then
    echo "Release build requires APPLE_SIGN_IDENTITY, APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD (or APPLE_PASSWORD)."
    exit 1
  fi

  codesign --force --deep --sign "$APPLE_SIGN_IDENTITY" --options runtime --timestamp "$APP_BUNDLE_DIR"

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE_DIR" "$ZIP_PATH"

  xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_NOTARY_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

  xcrun stapler staple "$APP_BUNDLE_DIR"
  xcrun stapler validate "$APP_BUNDLE_DIR"
  spctl --assess --type execute -vv "$APP_BUNDLE_DIR"
else
  codesign --force --deep --sign - "$APP_BUNDLE_DIR"
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
