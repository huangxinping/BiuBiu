#!/bin/bash
# Builds dist/BiuBiu.app (universal) and dist/BiuBiu-<version>.zip.
#
# Environment:
#   VERSION         marketing version, default "0.0.0-dev"
#   SIGN_IDENTITY   SHA-1 hash or name of the signing identity; ad-hoc ("-") when unset
#   SIGN_KEYCHAIN   keychain that holds SIGN_IDENTITY (optional)
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
# https://github.com/<owner>/<repo>, or empty when there is no GitHub remote (About hides its links then).
REPO_URL="$(git remote get-url origin 2>/dev/null | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##' || true)"
APP="dist/BiuBiu.app"

swift build -c release --arch arm64 --arch x86_64 --product BiuBiu
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP" dist/BiuBiu-*.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/BiuBiu" "$APP/Contents/MacOS/BiuBiu"
sed -e "s|__VERSION__|$VERSION|" -e "s|__BUILD__|$BUILD_NUMBER|" -e "s|__REPO_URL__|$REPO_URL|" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
cp -R Resources/*.lproj "$APP/Contents/Resources/"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

SIGN_ARGS=(--force --timestamp=none --sign "$SIGN_IDENTITY")
if [[ -n "${SIGN_KEYCHAIN:-}" ]]; then
  SIGN_ARGS+=(--keychain "$SIGN_KEYCHAIN")
fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "dist/BiuBiu-$VERSION.zip"
echo "Built $APP and dist/BiuBiu-$VERSION.zip (signed with: $SIGN_IDENTITY)"
