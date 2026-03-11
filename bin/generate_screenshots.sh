#!/bin/bash
# Generate App Store screenshots for all required device sizes.
# Launches the app in each simulator, waits, then captures screenshots.
#
# Usage: ./bin/generate_screenshots.sh
#
# Requirements:
#   - Xcode with iOS Simulator installed
#   - The app scheme "DnDTextRPG" must build successfully
#
# App Store required screenshot sizes:
#   iPhone 6.9"  — iPhone 16 Pro Max  (1320x2868)
#   iPhone 6.5"  — iPhone 15 Plus     (1290x2796)
#   iPad 13"     — iPad Pro 13-inch   (2064x2752)
#   iPad 12.9"   — iPad Pro 12.9"     (2048x2732)

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/ios/DnDTextRPG/DnDTextRPG.xcodeproj"
SCHEME="DnDTextRPG"
OUTDIR="$REPO_ROOT/screendumps"
DERIVED="/private/tmp/dnd_screenshots_build"

mkdir -p "$OUTDIR"

# Device simulators to capture (name must match Xcode simulator names)
declare -A DEVICES
DEVICES=(
    ["iPhone_16_Pro_Max"]="iPhone 16 Pro Max"
    ["iPhone_15_Plus"]="iPhone 15 Plus"
    ["iPad_Pro_13"]="iPad Pro 13-inch (M4)"
    ["iPad_Pro_12_9"]="iPad Pro (12.9-inch) (6th generation)"
)

echo "=== Building for iOS Simulator ==="
xcodebuild -scheme "$SCHEME" \
    -project "$PROJECT" \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    -quiet 2>&1

APP_PATH=$(find "$DERIVED" -name "DnDTextRPG.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app."
    exit 1
fi
echo "App: $APP_PATH"

BUNDLE_ID="com.timbaloo.dnd.textrpg"

for key in "${!DEVICES[@]}"; do
    SIM_NAME="${DEVICES[$key]}"
    echo ""
    echo "=== $SIM_NAME ($key) ==="

    # Find the simulator UDID
    UDID=$(xcrun simctl list devices available -j | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devs in data.get('devices', {}).items():
    for d in devs:
        if d['name'] == '$SIM_NAME' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || true

    if [ -z "$UDID" ]; then
        echo "  Simulator '$SIM_NAME' not found — skipping."
        continue
    fi

    echo "  UDID: $UDID"

    # Boot the simulator
    xcrun simctl boot "$UDID" 2>/dev/null || true
    echo "  Booted."

    # Install and launch the app
    xcrun simctl install "$UDID" "$APP_PATH"
    xcrun simctl launch "$UDID" "$BUNDLE_ID"
    echo "  App launched. Waiting 5s for UI to settle..."
    sleep 5

    # Capture screenshot
    SCREENSHOT="$OUTDIR/${key}.png"
    xcrun simctl io "$UDID" screenshot "$SCREENSHOT"
    echo "  Saved: $SCREENSHOT"

    # Terminate the app
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

    # Shutdown the simulator
    xcrun simctl shutdown "$UDID" 2>/dev/null || true
done

echo ""
echo "=== Screenshots saved to $OUTDIR ==="
ls -la "$OUTDIR"/*.png 2>/dev/null
