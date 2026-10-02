#!/bin/bash
# Builds Move.app into ./dist.
#   --install   copy it to /Applications and launch it
#   --release   build a universal (Apple silicon + Intel) app and zip it to dist/Move.zip
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH_FLAGS=()
[[ "${1:-}" == "--release" ]] && ARCH_FLAGS=(--arch arm64 --arch x86_64)

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Move"

if [ ! -f Resources/AppIcon.icns ]; then
    TMP="$(mktemp -d)/AppIcon.iconset"
    swift scripts/make_icon.swift "$TMP"
    iconutil -c icns "$TMP" -o Resources/AppIcon.icns
fi

APP=dist/Move.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Move"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--release" ]]; then
    rm -f dist/Move.zip
    ditto -c -k --keepParent "$APP" dist/Move.zip
    echo "Zipped dist/Move.zip"
fi

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Move 2>/dev/null || true
    rm -rf /Applications/Move.app
    cp -R "$APP" /Applications/Move.app
    open /Applications/Move.app
    echo "Installed to /Applications/Move.app"
fi
