#!/bin/bash
# Stops TouchBar Flicker Fix and removes what install.sh created.
set -euo pipefail

LABEL=io.github.gbili.TouchBarOff
APP="$HOME/Applications/TouchBar Flicker Fix.app"
OLD_APP="$HOME/Applications/TouchBarOff.app"
BINARY="$APP/Contents/MacOS/TouchBarFlickerFix"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL"
fi

# After the menu bar item has stopped, or it would darken the bar again at once.
if [ -x "$BINARY" ]; then
    "$BINARY" on
    echo "The Touch Bar is on again."
fi

rm -f "$AGENT"
rm -rf "$APP"
rm -rf "$OLD_APP"

echo "TouchBar Flicker Fix is removed."
