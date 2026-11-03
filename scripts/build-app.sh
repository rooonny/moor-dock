#!/bin/sh
# Builds build/Moor.app with an ad-hoc signature.
set -eu

cd "$(dirname "$0")/.."
swift build -c release

app="build/Moor.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Moor" "$app/Contents/MacOS/Moor"
cp Resources/Info.plist "$app/Contents/Info.plist"
mkdir -p "$app/Contents/Resources"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"

echo "Built $app"
