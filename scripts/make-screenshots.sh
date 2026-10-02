#!/bin/bash
# Renders the README screenshots (docs/images) from made-up demo files; see Sources/BiuBiu/ScreenshotMode.swift.
# Runs the bare build, not the .app: screencapture is then attributed to your terminal, which needs
# Screen Recording permission, and the display must be awake.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-docs/images}"
BIUBIU="$(scripts/dev-binary.sh)"
# One set per language the app ships (Resources/*.lproj), named panel-<language>.jpg and so on.
for lproj in Resources/*.lproj; do
  language="$(basename "$lproj" .lproj)"
  "$BIUBIU" --screenshots "$OUT" -AppleLanguages "($language)"
done
