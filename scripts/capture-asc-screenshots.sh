#!/usr/bin/env bash
# Capture App Store screenshots on the iPhone 14 Plus simulator (1284×2778 → APP_IPHONE_65).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${SIM_UDID:-2BB38CC5-F3B0-40AA-AF53-006972D3DB68}"
BUNDLE="com.antigravity.billsmanager"
OUT="$ROOT/screenshots/APP_IPHONE_65"
SCHEME="BillsManager"

mkdir -p "$OUT"

echo "==> Boot iPhone 14 Plus ($UDID)"
xcrun simctl shutdown "$UDID" 2>/dev/null || true
sleep 1
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID"

echo "==> Build & install"
xcodebuild -project "$ROOT/BillsManager.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug \
  build \
  | tail -20

APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData/BillsManager-*/Build/Products/Debug-iphonesimulator/BillsManager.app -maxdepth 0 2>/dev/null | head -1)"
if [[ -z "$APP_PATH" ]]; then
  echo "BillsManager.app not found in DerivedData" >&2
  exit 1
fi

xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"

xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --batteryState charged \
  --batteryLevel 100 \
  --operatorName "" 2>/dev/null || true

xcrun simctl ui "$UDID" appearance light 2>/dev/null || true

capture() {
  local tab="$1"
  local file="$2"
  echo "==> Screen $tab → $file"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 0.8
  xcrun simctl launch "$UDID" "$BUNDLE" -AppleLanguages "(en)" -screenshotDemo -screenshotTab "$tab"
  sleep 5
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
  osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
  sleep 0.4
  xcrun simctl io "$UDID" screenshot "$OUT/$file"
}

capture Dashboard 01-dashboard.png
capture Bills 02-bills.png
capture Calendar 03-calendar.png
capture Analytics 04-analytics.png
capture Settings 05-settings.png

echo "==> Wrote:"
ls -la "$OUT"
sips -g pixelWidth -g pixelHeight "$OUT"/*.png | paste - -
echo "Done."
