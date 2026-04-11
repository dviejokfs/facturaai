#!/bin/bash
set -euo pipefail

# FacturaAI App Store Screenshot Capture
# Captures all tabs across all devices and languages.
#
# Usage:
#   ./scripts/capture-screenshots.sh [path/to/FacturaAI.app]
#
# The app must support these launch arguments:
#   -UITestScreenshotMode YES    — seeds mock data, skips auth
#   -ScreenshotTab N             — opens tab N (0=Dashboard, 1=Invoices, 2=Export, 3=Settings)
#   -ScreenshotScrollDown        — scrolls the view down (for Dashboard charts)
#
# To retake screenshots:
#   1. Edit mock data in ScreenshotData.swift
#   2. Run: xcodebuild build ... (or use take-screenshots.sh which builds first)
#   3. Run this script

APP_PATH="${1:-$(find "$(dirname "$0")/../.build/screenshots" -name "FacturaAI.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)}"
OUTPUT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)/marketing/screenshots/raw"
BUNDLE_ID="ee.blocklyne.invoscanai"

if [ -z "$APP_PATH" ]; then
  echo "Error: No built app found. Pass path as argument or run xcodebuild first."
  exit 1
fi

echo "=== FacturaAI Screenshot Capture ==="
echo "App: $APP_PATH"
echo "Output: $OUTPUT_DIR"
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
  echo "Available devices:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10
  exit 1
fi

LANGUAGES=("en" "es")

# Screens: "tab_index:filename" or "tab_index_scroll:filename" for scrolled captures
SCREENS=(
  "0:01_Dashboard"
  "0_scroll:02_Dashboard_Charts"
  "1:03_Invoices"
  "2:04_Export"
  "3:05_Settings"
)

capture_screen() {
  local UDID="$1"
  local LANG="$2"
  local DIR="$3"
  local SCREEN_SPEC="$4"

  local SPEC="${SCREEN_SPEC%%:*}"
  local FILENAME="${SCREEN_SPEC##*:}"
  local TAB_INDEX="${SPEC%%_*}"
  local SCROLL=""

  if [[ "$SPEC" == *"_scroll"* ]]; then
    SCROLL="YES"
  fi

  # Terminate previous instance
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 0.5

  # Build launch arguments
  local LAUNCH_ARGS=(
    -UITestScreenshotMode YES
    -ScreenshotTab "$TAB_INDEX"
    -AppleLanguages "($LANG)"
    -AppleLocale "${LANG}"
  )

  if [ -n "$SCROLL" ]; then
    LAUNCH_ARGS+=(-ScreenshotScrollDown)
  fi

  # Launch app with arguments
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "${LAUNCH_ARGS[@]}" 2>/dev/null

  # Wait for app to load and render
  sleep 4

  # Capture screenshot
  xcrun simctl io "$UDID" screenshot "$DIR/${FILENAME}.png" 2>/dev/null
  echo "    ✓ ${FILENAME}"
}

capture_device() {
  local DEVICE_NAME="$1"
  local UDID="$2"
  local DEVICE_SAFE=$(echo "$DEVICE_NAME" | sed 's/^  *//' | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')

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

    echo "  [$LANG]"

    for SCREEN in "${SCREENS[@]}"; do
      capture_screen "$UDID" "$LANG" "$DIR" "$SCREEN"
    done

    echo ""
  done

  # Shutdown
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  echo ""
}

for ENTRY in "${DEVICES[@]}"; do
  IFS='|' read -r NAME UDID <<< "$ENTRY"
  capture_device "$NAME" "$UDID"
done

# Count total screenshots
TOTAL=$(find "$OUTPUT_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')

echo "=== Done! $TOTAL screenshots in: $OUTPUT_DIR ==="
echo ""
echo "Screens captured per device per language:"
for SCREEN in "${SCREENS[@]}"; do
  echo "  - ${SCREEN##*:}"
done
