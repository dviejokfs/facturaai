#!/bin/bash
set -euo pipefail

# FacturaAI App Store Screenshot Capture
# Captures the Dashboard screen across all devices and languages.
# For full multi-tab screenshots, use Xcode UI tests.

APP_PATH="${1:-$(find "$(dirname "$0")/../.build/screenshots" -name "FacturaAI.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)}"
OUTPUT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)/marketing/screenshots/raw"
BUNDLE_ID="ee.blocklyne.invoscanai"

if [ -z "$APP_PATH" ]; then
  echo "Error: No built app found. Run xcodebuild first."
  exit 1
fi

echo "=== FacturaAI Screenshot Capture ==="
echo "App: $APP_PATH"
echo "Output: $OUTPUT_DIR"
echo ""

# Device configs: "Name|UDID"
declare -a DEVICES
while IFS= read -r line; do
  NAME=$(echo "$line" | sed 's/ (.*//')
  UDID=$(echo "$line" | grep -oE '[A-F0-9-]{36}')
  DEVICES+=("$NAME|$UDID")
done < <(xcrun simctl list devices available | grep -E "iPhone 17 Pro Max|iPhone 17 Pro |iPad Pro 13-inch")

LANGUAGES=("en" "es")

capture_device() {
  local DEVICE_NAME="$1"
  local UDID="$2"
  local DEVICE_SAFE=$(echo "$DEVICE_NAME" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')

  echo "=== $DEVICE_NAME ==="

  # Boot
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

  # Install
  xcrun simctl install "$UDID" "$APP_PATH"

  for LANG in "${LANGUAGES[@]}"; do
    local DIR="$OUTPUT_DIR/${DEVICE_SAFE}/${LANG}"
    mkdir -p "$DIR"

    echo "  [$LANG] Launching..."

    # Kill any previous instance
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1

    # Launch with screenshot mode + language
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
      -UITestScreenshotMode YES \
      -AppleLanguages "($LANG)" \
      -AppleLocale "${LANG}" 2>/dev/null

    # Wait for app to load and render
    sleep 5

    # Capture Dashboard
    xcrun simctl io "$UDID" screenshot "$DIR/01_Dashboard.png" 2>/dev/null
    echo "  [$LANG] ✓ 01_Dashboard"

    sleep 1

    # Terminate for next language
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  done

  # Shutdown
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  echo ""
}

for ENTRY in "${DEVICES[@]}"; do
  IFS='|' read -r NAME UDID <<< "$ENTRY"
  capture_device "$NAME" "$UDID"
done

echo "=== Done! Screenshots in: $OUTPUT_DIR ==="
echo ""
echo "Note: Only the Dashboard screen was captured automatically."
echo "For all tabs, open Xcode → Run on simulator with -UITestScreenshotMode"
echo "and use Cmd+S to screenshot each tab manually."
