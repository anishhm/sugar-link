#!/bin/zsh
# Run daily by launchd (see schedule.sh). Reinstalls Sugar Link on the watch when the last
# successful install is 5 or more days old, so the free Apple ID's 7-day limit never runs out.
# If the watch can't be reached, it tries again the next day and shows a notification.
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STATE="$HOME/Library/Application Support/SugarLink"
STAMP="$STATE/last-install"
MAX_AGE_DAYS=5
mkdir -p "$STATE"

notify() { osascript -e "display notification \"$1\" with title \"Sugar Link\"" >/dev/null 2>&1 || true; }

if [[ -f "$STAMP" ]]; then
  age=$(( ( $(date +%s) - $(stat -f %m "$STAMP") ) / 86400 ))
  if (( age < MAX_AGE_DAYS )); then
    echo "$(date): last install $age day(s) ago, nothing to do."
    exit 0
  fi
fi

echo "$(date): reinstalling..."
if ./scripts/reinstall.sh; then
  touch "$STAMP"
  notify "Reinstalled on your watch. Good for another 7 days."
else
  notify "Couldn't reinstall on your watch. Unlock the iPhone and watch near the Mac; I'll try again tomorrow."
  exit 1
fi
