#!/bin/bash
set -euo pipefail

# FacturaAI App Preview Recorder
# Records a ~25-second App Store preview video for all devices and languages.
#
# The app must be built first (see take-screenshots.sh for build command,
# or run this script which will build if needed).
#
# App launch args used:
#   -UITestPreviewMode YES   — auto-navigates tabs (Dashboard → charts → top
#                               → Invoices → Export → Settings → Dashboard)
#   -UITestScreenshotMode YES — seeds mock data so the app is fully populated
#
# Output: marketing/previews/raw/{device}/{lang}/preview.mov
#         marketing/previews/trimmed/{device}/{lang}/preview.mp4  (App Store–ready)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="${1:-$(find "$PROJECT_DIR/.build/screenshots" -name "FacturaAI.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)}"
OUT_RAW="$(cd "$PROJECT_DIR/../.." && pwd)/marketing/previews/raw"
OUT_FINAL="$(cd "$PROJECT_DIR/../.." && pwd)/marketing/previews/trimmed"
BUNDLE_ID="ee.blocklyne.invoscanai"

RECORD_SECONDS=28  # record a bit longer than the in-app tour to catch the end
FINAL_SECONDS=28   # max App Store allows is 30s, min is 15s

if [ -z "$APP_PATH" ]; then
  echo "Error: No built app found. Build first with:"
  echo "  xcodebuild build -project FacturaAI.xcodeproj -scheme FacturaAI \\"
  echo "    -destination 'generic/platform=iOS Simulator' \\"
  echo "    -derivedDataPath .build/screenshots"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg not found. Install with: brew install ffmpeg"
  exit 1
fi

echo "=== FacturaAI App Preview Recorder ==="
echo "App: $APP_PATH"
echo "Raw output:   $OUT_RAW"
echo "Final output: $OUT_FINAL"
echo ""

# Device configs: "Name|UDID"
declare -a DEVICES
while IFS= read -r line; do
  NAME=$(echo "$line" | sed 's/^ *//' | sed 's/ (.*//')
  UDID=$(echo "$line" | grep -oE '[A-F0-9-]{36}')
  DEVICES+=("$NAME|$UDID")
done < <(xcrun simctl list devices available | grep -E "iPhone 17 Pro Max|iPhone 17 Pro |iPad Pro 13-inch")

if [ ${#DEVICES[@]} -eq 0 ]; then
  echo "Error: No matching simulators found."
  exit 1
fi

LANGUAGES=("en" "es")

record_device_lang() {
  local DEVICE_NAME="$1"
  local UDID="$2"
  local LANG="$3"
  local DEVICE_SAFE=$(echo "$DEVICE_NAME" | sed 's/^  *//' | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')

  local RAW_DIR="$OUT_RAW/${DEVICE_SAFE}/${LANG}"
  local FINAL_DIR="$OUT_FINAL/${DEVICE_SAFE}/${LANG}"
  mkdir -p "$RAW_DIR" "$FINAL_DIR"

  local RAW_FILE="$RAW_DIR/preview.mov"
  local FINAL_FILE="$FINAL_DIR/preview.mp4"

  echo "  [$LANG] Starting recording..."

  # Kill any previous instance
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 0.5

  # Start recording in background
  rm -f "$RAW_FILE"
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW_FILE" &
  local RECORD_PID=$!

  # Give recorder a moment to start
  sleep 1

  # Launch app in preview mode with seeded mock data
  xcrun simctl launch "$UDID" "$BUNDLE_ID" \
    -UITestPreviewMode YES \
    -UITestScreenshotMode YES \
    -AppleLanguages "($LANG)" \
    -AppleLocale "${LANG}" >/dev/null

  # Wait for the tour to play out
  sleep "$RECORD_SECONDS"

  # Stop recording (SIGINT so recordVideo flushes the file)
  kill -INT "$RECORD_PID" 2>/dev/null || true
  wait "$RECORD_PID" 2>/dev/null || true

  # Terminate app
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

  echo "  [$LANG] ✓ raw: $(basename "$RAW_FILE")"

  # Convert to App Store–ready format: H.264, exact duration, no audio, standard pixel format
  ffmpeg -y -hide_banner -loglevel error \
    -i "$RAW_FILE" \
    -t "$FINAL_SECONDS" \
    -c:v libx264 -pix_fmt yuv420p \
    -profile:v high -level 4.2 \
    -r 30 \
    -movflags +faststart \
    -an \
    "$FINAL_FILE"

  echo "  [$LANG] ✓ final: $(basename "$FINAL_FILE") ($(du -h "$FINAL_FILE" | cut -f1))"
}

record_device() {
  local DEVICE_NAME="$1"
  local UDID="$2"

  echo "=== $DEVICE_NAME ==="

  # Boot simulator
  xcrun simctl boot "$UDID" 2>/dev/null || true
  sleep 3

  # Clean status bar
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4 \
    --cellularMode active 2>/dev/null || true

  # Install app
  xcrun simctl install "$UDID" "$APP_PATH"

  for LANG in "${LANGUAGES[@]}"; do
    record_device_lang "$DEVICE_NAME" "$UDID" "$LANG"
  done

  # Shutdown simulator
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  echo ""
}

for ENTRY in "${DEVICES[@]}"; do
  IFS='|' read -r NAME UDID <<< "$ENTRY"
  record_device "$NAME" "$UDID"
done

TOTAL=$(find "$OUT_FINAL" -name "*.mp4" 2>/dev/null | wc -l | tr -d ' ')
echo "=== Done! $TOTAL preview videos in: $OUT_FINAL ==="
echo ""
echo "App Store Connect upload: previews must be 15-30s, under 500MB, H.264, 30fps."
echo "Review each .mp4 before uploading — in-app animations can be choppy if the"
echo "simulator was under load during recording."
