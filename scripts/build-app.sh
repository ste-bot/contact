#!/bin/zsh
# Builds build/Contact.app from the Swift package. Needs only the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Contact.app"
swift build -c release --product ProofPositive

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ProofPositive "$APP/Contents/MacOS/ProofPositive"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Bundled typefaces (OFL): Archivo, Host Grotesk, Doto. Info.plist's ATSApplicationFontsPath registers them.
fonts=(Resources/Fonts/*(N))
if (( ${#fonts} )); then
  mkdir -p "$APP/Contents/Resources/Fonts"
  cp Resources/Fonts/* "$APP/Contents/Resources/Fonts/"
fi

# The CONTACT mark, shared by the app and the icon.
mkdir -p "$APP/Contents/Resources/Brand"
cp Resources/Brand/wax-box.json "$APP/Contents/Resources/Brand/"

# Icon: render when missing or when the mark changes, then cache in Resources/.
if [[ ! -f Resources/AppIcon.icns || Resources/Brand/wax-box.json -nt Resources/AppIcon.icns || scripts/make-icon.swift -nt Resources/AppIcon.icns ]]; then
  ICONSET=$(mktemp -d)/AppIcon.iconset
  mkdir -p "$ICONSET"
  swift scripts/make-icon.swift "$ICONSET/icon_512x512@2x.png" Resources/Brand/wax-box.json
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run on this Mac.
codesign --force --sign - "$APP"
echo "Built $APP"
