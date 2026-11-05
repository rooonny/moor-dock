#!/bin/sh
# Builds Moor.dmg and Moor.zip in build/release with a universal (Apple silicon and Intel) app, signed ad-hoc.
# Resources/dmg-DS_Store holds the layout of the disk image window, saved from Finder.
set -eu

cd "$(dirname "$0")/.."
# Each architecture gets its own build folder because they would otherwise share an output path.
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --scratch-path ".build/release-$arch"
done

out="build/release"
app="$out/Moor.app"
rm -rf "$out"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create \
    "$(swift build -c release --arch arm64 --scratch-path .build/release-arm64 --show-bin-path)/Moor" \
    "$(swift build -c release --arch x86_64 --scratch-path .build/release-x86_64 --show-bin-path)/Moor" \
    -output "$app/Contents/MacOS/Moor"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"

ditto -c -k --keepParent "$app" "$out/Moor.zip"

stage="$out/dmg"
mkdir -p "$stage/.background"
cp -R "$app" "$stage/Moor.app"
ln -s /Applications "$stage/Applications"
cp Resources/dmg-background.tiff "$stage/.background/background.tiff"
cp Resources/dmg-DS_Store "$stage/.DS_Store"
hdiutil create -quiet -ov -volname Moor -srcfolder "$stage" -fs HFS+ -format UDZO "$out/Moor.dmg"
rm -rf "$stage"

echo "Built $out/Moor.dmg and $out/Moor.zip"
