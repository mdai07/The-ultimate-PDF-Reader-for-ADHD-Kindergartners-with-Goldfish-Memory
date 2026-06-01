#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGE="${SOURCE_IMAGE:-}"
if [[ $# -gt 0 && -f "$1" ]]; then
    SOURCE_IMAGE="$1"
    shift
fi
ICON_CHOICE="${1:-wand}"
APP_NAME="uprakigo"
APP_EXECUTABLE="uprakigo"
APP_BUNDLE_IDENTIFIER="app.uprakigo.reader"
DIST_DIR="$ROOT_DIR/dist"
STAMP="$(date +%Y%m%d-%H%M%S)"
RELEASE_DIR="$DIST_DIR/releases/$APP_NAME-$STAMP"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICONSET_DIR="$DIST_DIR/AIReader.iconset"
ICNS_FILE="$DIST_DIR/AIReader.icns"
APP_ICON_FILE="$APP_NAME.icns"
DMG_FILE="$DIST_DIR/$APP_NAME-0.1-$ICON_CHOICE-$STAMP.dmg"

mkdir -p "$DIST_DIR" "$RELEASE_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

if [[ -n "$SOURCE_IMAGE" ]]; then
    swift "$ROOT_DIR/scripts/generate_release_assets.swift" "$SOURCE_IMAGE" "$DIST_DIR"
else
    swift "$ROOT_DIR/scripts/generate_release_assets.swift" "$DIST_DIR"
fi
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
for emoji_iconset in "$DIST_DIR"/AIReaderEmoji-*.iconset; do
    [[ -d "$emoji_iconset" ]] || continue
    iconutil -c icns "$emoji_iconset" -o "${emoji_iconset%.iconset}.icns"
done
for alt_iconset in "$DIST_DIR"/AIReaderAlt-*.iconset; do
    [[ -d "$alt_iconset" ]] || continue
    iconutil -c icns "$alt_iconset" -o "${alt_iconset%.iconset}.icns"
done

case "$ICON_CHOICE" in
    wand)
        SELECTED_ICNS="$ICNS_FILE"
        ;;
    emoji-01)
        SELECTED_ICNS="$DIST_DIR/AIReaderEmoji-01.icns"
        ;;
    emoji-02)
        SELECTED_ICNS="$DIST_DIR/AIReaderEmoji-02.icns"
        ;;
    emoji-03)
        SELECTED_ICNS="$DIST_DIR/AIReaderEmoji-03.icns"
        ;;
    alt-01)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-01.icns"
        ;;
    alt-02)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-02.icns"
        ;;
    alt-03)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-03.icns"
        ;;
    alt-04)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-04.icns"
        ;;
    alt-05)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-05.icns"
        ;;
    alt-06)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-06.icns"
        ;;
    alt-07)
        SELECTED_ICNS="$DIST_DIR/AIReaderAlt-07.icns"
        ;;
    *)
        printf 'unknown icon choice: %s\nexpected: wand, emoji-01, emoji-02, emoji-03, alt-01, alt-02, alt-03, alt-04, alt-05, alt-06, alt-07\n' "$ICON_CHOICE" >&2
        exit 64
        ;;
esac

swift build -c release --package-path "$ROOT_DIR"

cp "$ROOT_DIR/.build/release/$APP_EXECUTABLE" "$MACOS_DIR/$APP_EXECUTABLE"
chmod 755 "$MACOS_DIR/$APP_EXECUTABLE"
/usr/bin/strip -S -x "$MACOS_DIR/$APP_EXECUTABLE"
cp "$SELECTED_ICNS" "$RESOURCES_DIR/$APP_ICON_FILE"

plutil -create xml1 "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_EXECUTABLE" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $APP_BUNDLE_IDENTIFIER" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.1" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $APP_NAME" "$INFO_PLIST"

codesign --force --deep --sign - "$APP_BUNDLE"

ln -s /Applications "$RELEASE_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$RELEASE_DIR" -format UDZO "$DMG_FILE"

printf '%s\n' "$APP_BUNDLE"
printf '%s\n' "$DMG_FILE"
