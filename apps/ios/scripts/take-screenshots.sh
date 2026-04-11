#!/bin/bash
set -euo pipefail

# App Store Screenshot Generator for FacturaAI
# Usage: ./scripts/take-screenshots.sh
#
# Prerequisites:
#   - Xcode installed with simulators
#   - App builds successfully
#
# To retake screenshots in the future:
#   1. Update mock data in ScreenshotData.swift
#   2. Run this script again

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/../marketing/screenshots/raw"

# Devices to screenshot (edit as needed)
DEVICES=(
  "iPhone 17 Pro Max"
  "iPhone 17 Pro"
  "iPad Pro 13-inch (M5)"
)

# Languages
LANGUAGES=("en" "es")

# Screens to capture — tab index and name
SCREENS=(
  "0:01_Dashboard"
  "0_scroll:02_Dashboard_Charts"
  "1:03_Invoices"
  "2:04_Export"
  "3:05_Settings"
)

echo "=== FacturaAI Screenshot Generator ==="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build the app for simulators
echo "Building FacturaAI for simulators..."
cd "$PROJECT_DIR"
xcodebuild build-for-testing \
  -project FacturaAI.xcodeproj \
  -scheme FacturaAI \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$PROJECT_DIR/.build/screenshots" \
  -quiet 2>&1 || {
    echo "Build failed. Falling back to manual screenshot mode..."
    echo ""
    echo "Please:"
    echo "  1. Open FacturaAI.xcodeproj in Xcode"
    echo "  2. Edit Scheme → Run → Arguments → Add '-UITestScreenshotMode'"
    echo "  3. Run on each simulator and take screenshots manually (Cmd+S)"
    echo "  4. Screenshots save to ~/Desktop by default"
    exit 1
}

# Find the built app
APP_PATH=$(find "$PROJECT_DIR/.build/screenshots" -name "FacturaAI.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [ -z "$APP_PATH" ]; then
  echo "Error: Could not find built app"
  exit 1
fi
echo "App built: $APP_PATH"
echo ""

for DEVICE in "${DEVICES[@]}"; do
  DEVICE_SAFE=$(echo "$DEVICE" | tr ' ' '_' | tr -d '()')

  # Find device UDID
  UDID=$(xcrun simctl list devices available | grep "$DEVICE" | head -1 | grep -oE '[A-F0-9-]{36}')
  if [ -z "$UDID" ]; then
    echo "⚠️  Simulator '$DEVICE' not found, skipping"
    continue
  fi

  echo "=== $DEVICE ($UDID) ==="

  # Boot simulator
  xcrun simctl boot "$UDID" 2>/dev/null || true

  # Wait for boot
  sleep 3

  # Override status bar (9:41, full battery, full signal)
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4 \
    --cellularMode active 2>/dev/null || true

  for LANG in "${LANGUAGES[@]}"; do
    echo "  Language: $LANG"
    LANG_DIR="$OUTPUT_DIR/$DEVICE_SAFE/$LANG"
    mkdir -p "$LANG_DIR"

    # Install app
    xcrun simctl install "$UDID" "$APP_PATH"

    # Launch with screenshot mode + language
    xcrun simctl terminate "$UDID" ee.blocklyne.invoscanai 2>/dev/null || true
    xcrun simctl launch "$UDID" ee.blocklyne.invoscanai \
      -UITestScreenshotMode YES \
      -AppleLanguages "($LANG)" \
      -AppleLocale "${LANG}_$(echo $LANG | tr '[:lower:]' '[:upper:]')"

    # Wait for app to load and settle
    sleep 4

    # Take screenshot of current screen (Dashboard)
    xcrun simctl io "$UDID" screenshot "$LANG_DIR/01_Dashboard.png"
    echo "    ✓ 01_Dashboard"

    sleep 1
    xcrun simctl io "$UDID" screenshot "$LANG_DIR/02_Dashboard_Full.png"
    echo "    ✓ 02_Dashboard_Full"

    # Note: simctl can't tap UI elements, so we capture what's visible
    # For tab navigation, the UI test approach is needed

    echo "  ✓ Done ($LANG)"
  done

  # Shutdown simulator
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  echo ""
done

echo "=== Screenshots saved to: $OUTPUT_DIR ==="
echo ""
echo "For full tab navigation screenshots, add a UI test target in Xcode:"
echo "  File → New → Target → UI Testing Bundle"
echo "  Then run: xcodebuild test -scheme FacturaAI -only-testing:FacturaAIUITests"
