#!/bin/zsh
# Rebuilds Sugar Link and installs it on your Apple Watch. Run it once a week:
# a free Apple ID's install expires after 7 days.
#   ./scripts/reinstall.sh              # uses the first Apple Watch it finds
#   ./scripts/reinstall.sh "My Watch"   # or name it (as shown by: xcrun devicectl list devices)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
[[ -d SugarLink.xcodeproj ]] || xcodegen -q

# Find the watch: the name you gave, or the first connected Apple Watch.
DEVICES=$(xcrun devicectl list devices 2>/dev/null)
if [[ $# -gt 0 ]]; then
  UDID=$(echo "$DEVICES" | grep -F "$1" | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1 || true)
else
  UDID=$(echo "$DEVICES" | grep "Apple Watch" | grep -E "connected|available" | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1 || true)
fi
[[ -n "${UDID:-}" ]] || { echo "No Apple Watch found. Unlock the iPhone and watch, keep them near the Mac, then try again."; exit 1; }
echo "Watch: $UDID"

echo "Building..."
# Compiler warnings are noise here; the full log is only shown if the build fails.
LOG=$(mktemp)
if ! xcodebuild -project SugarLink.xcodeproj -scheme "Sugar Link" -configuration Release \
  -destination "id=$UDID" -derivedDataPath build/device -allowProvisioningUpdates build >"$LOG" 2>&1; then
  tail -40 "$LOG"
  echo "Build failed. Check that you picked your Team for both targets (see the README)."
  exit 1
fi

APP=$(ls -d build/device/Build/Products/Release-watchos/*.app | head -1)
echo "Installing..."
xcrun devicectl device install app --device "$UDID" "$APP"
echo "Done. Sugar Link is installed for another 7 days."
