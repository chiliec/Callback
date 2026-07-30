#!/usr/bin/env bash
# Captures App Store screenshots into docs/store-assets/ios/.
# Usage: scripts/capture-screenshots.sh            (defaults to iPhone 16 Pro Max)
#        DEVICE="iPhone 17 Pro Max" scripts/capture-screenshots.sh
set -euo pipefail
DEVICE="${DEVICE:-iPhone 16 Pro Max}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/store-assets/ios"
mkdir -p "$OUT"
rm -f "$OUT"/*.png

# Regenerate first: a newly added test file is invisible to xcodebuild until the
# project is rebuilt, and -only-testing then silently matches nothing.
(cd "$ROOT" && xcodegen generate >/dev/null)

# SCREENSHOT_DIR comes from the scheme's test action (see project.yml) — passing it
# on the xcodebuild command line does not reach the UI test runner process.
xcodebuild test \
  -project "$ROOT/Callback.xcodeproj" \
  -scheme Callback \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
  -only-testing:CallbackUITests/ScreenshotTests

echo "--- captured ---"
count=0
for f in "$OUT"/*.png; do
  [ -f "$f" ] || continue
  count=$((count + 1))
  printf "%s  " "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2} END {print ""}'
done

# "TEST SUCCEEDED" with zero tests executed is a real failure mode — catch it.
if [ "$count" -lt 6 ]; then
  echo "FAIL captured $count screenshots, expected 6" >&2
  exit 1
fi
