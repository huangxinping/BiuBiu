#!/bin/bash
# Builds the bare BiuBiu executable for the developer modes (--screenshots, --promo-sprites) and prints its
# path. Localized strings are looked up next to a bare executable, so the .lproj folders are copied there.
set -euo pipefail

cd "$(dirname "$0")/.."
swift build --product BiuBiu >&2
BIN_DIR="$(swift build --show-bin-path)"
cp -R Resources/*.lproj "$BIN_DIR/"
echo "$BIN_DIR/BiuBiu"
