#!/bin/bash
# Builds Planner.app into ./build.
#   --install  copies it to /Applications and opens it
#   --package  also makes build/Planner.zip (app, illustrated PDF guides, README, LICENSE in English and Portuguese)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Planner.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

# Universal binary: runs on Apple chip and Intel Macs.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.0" \
    Sources/*.swift -o "build/Planner-$arch"
done
lipo -create build/Planner-arm64 build/Planner-x86_64 -output "$APP/Contents/MacOS/Planner"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

swiftc -O make-icon.swift -o build/make-icon
build/make-icon build/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--package" ]]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  PKG="build/package/Planner"
  mkdir -p "$PKG"
  cp docs/guide.html docs/guia.html build/
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
    --print-to-pdf="$PKG/Installation Guide.pdf" "file://$PWD/build/guide.html" 2>/dev/null
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
    --print-to-pdf="$PKG/Guia de instalação.pdf" "file://$PWD/build/guia.html" 2>/dev/null
  cp -R "$APP" "$PKG/"
  cp README.txt LICENSE.txt LEIA-ME.txt "$PKG/"
  cp LICENCA.txt "$PKG/LICENÇA.txt"
  ditto -c -k --keepParent "$PKG" build/Planner.zip
  echo "Packaged build/Planner.zip"
fi

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Planner 2>/dev/null || true
  sleep 0.5
  rm -rf /Applications/Planner.app
  cp -R "$APP" /Applications/Planner.app
  open /Applications/Planner.app
  echo "Installed /Applications/Planner.app"
fi
