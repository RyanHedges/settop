source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"
import "state.sh"

blue_pprint "Configuring Dock..."

NEEDS_DOCK_RESTART=false

# com.apple.dock autohide: Automatically hide and show the Dock.
# Values: true (1), false (0)
# Docs: System Preferences > Dock & Menu Bar > Automatically hide and show the Dock
TARGET_AUTOHIDE=true
CURRENT_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo "0")
if [ "$CURRENT_AUTOHIDE" != "1" ] && [ "$CURRENT_AUTOHIDE" != "true" ] && [ "$CURRENT_AUTOHIDE" != "YES" ]; then
  grn_print "Set Dock auto-hide to $TARGET_AUTOHIDE..."
  defaults write com.apple.dock autohide -bool "$TARGET_AUTOHIDE" || red_print "Failed to set Dock auto-hide"
  NEEDS_DOCK_RESTART=true
else
  yel_print "Dock auto-hide already $TARGET_AUTOHIDE. Skipping..."
fi

if [ "$NEEDS_DOCK_RESTART" = true ]; then
  blue_pprint "Applying Dock changes by running killall Dock..."
  killall Dock || red_print "Failed to kill Dock"
fi
