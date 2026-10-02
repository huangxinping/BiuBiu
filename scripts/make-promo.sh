#!/bin/bash
# Renders the promo video and the README teaser from made-up demo files; nothing is recorded from the screen.
#   1. `BiuBiu --promo-sprites` draws the real panel, in dark mode, in every state the video shows.
#   2. BiuBiuPromo animates those around drawn scenes, synthesizes the soundtrack and encodes with ffmpeg.
# Writes dist/biubiu-promo.mp4 (upload it to GitHub and paste its URL into README.md) and
# docs/images/biubiu-teaser.gif. Needs ffmpeg (brew install ffmpeg).
set -euo pipefail

cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

"$(scripts/dev-binary.sh)" --promo-sprites "$WORK/sprites" -AppleLanguages "(en)"

swift build -c release --product BiuBiuPromo
"$(swift build -c release --show-bin-path)/BiuBiuPromo" \
  --sprites "$WORK/sprites" --icon Resources/AppIcon.icns --out "$WORK/out"

mkdir -p dist docs/images
mv "$WORK/out/biubiu-promo.mp4" dist/
mv "$WORK/out/biubiu-teaser.gif" docs/images/
echo "Wrote dist/biubiu-promo.mp4 and docs/images/biubiu-teaser.gif"
