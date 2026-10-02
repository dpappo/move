#!/bin/bash
# Installs the latest Move release:
#   curl -fsSL https://raw.githubusercontent.com/dpappo/move/main/scripts/install.sh | bash
set -euo pipefail

URL="https://github.com/dpappo/move/releases/latest/download/Move.zip"
DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Move…"
curl -fsSL "$URL" -o "$TMP/Move.zip"
ditto -x -k "$TMP/Move.zip" "$TMP"

pkill -x Move 2>/dev/null || true
rm -rf "$DEST/Move.app"
mv "$TMP/Move.app" "$DEST/Move.app"
xattr -dr com.apple.quarantine "$DEST/Move.app" 2>/dev/null || true

open "$DEST/Move.app"
echo "Installed to $DEST/Move.app. Look for the walking figure in your menu bar."
