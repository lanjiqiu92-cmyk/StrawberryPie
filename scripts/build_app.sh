#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$PROJECT_DIR/dist/草莓派.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
mkdir -p .swiftpm-cache .swiftpm-config .swiftpm-security .module-cache
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.module-cache" \
swift build -c release \
    --disable-sandbox \
    --cache-path .swiftpm-cache \
    --config-path .swiftpm-config \
    --security-path .swiftpm-security \
    --scratch-path .build-release \
    --manifest-cache local

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
rm -f "$CONTENTS_DIR/Resources/FamilyFour.png" "$CONTENTS_DIR/Resources/FamilyFour-chroma.png"
cp ".build-release/release/ChocolatePie" "$CONTENTS_DIR/MacOS/ChocolatePie"

if [ -f "$PROJECT_DIR/ChocolatePie.png" ]; then
    cp "$PROJECT_DIR/ChocolatePie.png" "$CONTENTS_DIR/Resources/ChocolatePie.png"
fi

if [ -f "$PROJECT_DIR/Resources/RoomCat.svg" ]; then
    cp "$PROJECT_DIR/Resources/RoomCat.svg" "$CONTENTS_DIR/Resources/RoomCat.svg"
fi

if [ -f "$PROJECT_DIR/Resources/TwoCats.png" ]; then
    cp "$PROJECT_DIR/Resources/TwoCats.png" "$CONTENTS_DIR/Resources/TwoCats.png"
fi

sed "s/@VERSION@/2.1.0/" "$PROJECT_DIR/scripts/Info.plist.template" > "$CONTENTS_DIR/Info.plist"
chmod +x "$CONTENTS_DIR/MacOS/ChocolatePie"

xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
