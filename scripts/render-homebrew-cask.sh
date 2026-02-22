#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <version> <sha256>"
  exit 1
fi

VERSION="$1"
SHA256="$2"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist/homebrew/Casks"
OUTPUT_FILE="$OUTPUT_DIR/sundown.rb"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_FILE" <<EOF
cask "sundown" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/seilk/sundown/releases/download/#{version}/Sundown-#{version}.zip",
      verified: "github.com/seilk/sundown/"
  name "Sundown"
  desc "Lightweight macOS menubar app for daily worktime boundary"
  homepage "https://github.com/seilk/sundown"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Sundown.app"

  zap trash: [
    "~/Library/Application Support/Sundown",
    "~/Library/Preferences/com.seilk.sundown.plist"
  ]
end
EOF

echo "Generated: $OUTPUT_FILE"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "cask_path=$OUTPUT_FILE" >> "$GITHUB_OUTPUT"
fi
