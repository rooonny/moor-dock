#!/bin/sh
# Builds Moor.dmg and Moor.zip in build/release with a universal (Apple silicon and Intel) app, signed ad-hoc.
# Arranging the disk image window uses Finder, so macOS may ask to allow automation the first time.
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
hdiutil create -quiet -ov -volname Moor -srcfolder "$stage" -fs HFS+ -format UDRW "$out/Moor-rw.dmg"

device="$(hdiutil attach -readwrite -noverify -noautoopen "$out/Moor-rw.dmg" | awk 'NR==1 {print $1}')"
osascript <<'SCRIPT'
tell application "Finder"
    tell disk "Moor"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 840, 520}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 96
        set background picture of options to file ".background:background.tiff"
        set position of item "Moor.app" of container window to {170, 190}
        set position of item "Applications" of container window to {470, 190}
        update without registering applications
        delay 1
        close
    end tell
end tell
SCRIPT
sync
hdiutil detach -quiet "$device"
hdiutil convert -quiet "$out/Moor-rw.dmg" -format UDZO -o "$out/Moor.dmg"
rm -rf "$stage" "$out/Moor-rw.dmg"

echo "Built $out/Moor.dmg and $out/Moor.zip"
