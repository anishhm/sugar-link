#!/bin/zsh
# Sets up (or removes) the automatic reinstall on this Mac.
#   ./scripts/schedule.sh          # install: checks every day at 21:00 and at login
#   ./scripts/schedule.sh remove   # stop and delete it
set -euo pipefail
cd "$(dirname "$0")/.."
LABEL="com.sugarlink.reinstall"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/SugarLink-reinstall.log"

if [[ "${1:-}" == "remove" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed."
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$PWD/scripts/auto-reinstall.sh</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
	<key>RunAtLoad</key><true/>
	<key>StandardOutPath</key><string>$LOG</string>
	<key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Scheduled. It checks every day at 21:00 (and at login) and reinstalls once the last install is 5 days old."
echo "Log: $LOG"
