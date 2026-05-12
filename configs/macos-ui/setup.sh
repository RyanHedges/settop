source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"
import "state.sh"

blue_pprint "Configuring UI..."

NEEDS_UI_RESTART=false

# AppleInterfaceStyleSwitchesAutomatically: Automatically switch between light and dark appearances based on time of day.
# Values: true (1), false (0 or delete key)
# Docs: System Preferences > General > Appearance > Auto
TARGET_APPEARANCE=true
CURRENT_APPEARANCE=$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || echo "")
if [ "$CURRENT_APPEARANCE" != "1" ] && [ "$CURRENT_APPEARANCE" != "true" ] && [ "$CURRENT_APPEARANCE" != "YES" ]; then
  grn_print "Set AppleInterfaceStyleSwitchesAutomatically to $TARGET_APPEARANCE..."
  defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool "$TARGET_APPEARANCE" || red_print "Failed to set AppleInterfaceStyleSwitchesAutomatically"
  require_restart "UI: Set automatic Light/Dark appearance switching to $TARGET_APPEARANCE"
else
  yel_print "AppleInterfaceStyleSwitchesAutomatically already $TARGET_APPEARANCE. Skipping..."
fi

# Battery Percentage Settings
# We use a single variable to control both the legacy (pre-Big Sur) and modern (Control Center) settings.
# Values: true, false
TARGET_SHOW_BATTERY_PERCENTAGE=true

if [ "$TARGET_SHOW_BATTERY_PERCENTAGE" = true ]; then
  LEGACY_BATTERY_PCT="YES"
else
  LEGACY_BATTERY_PCT="NO"
fi

# com.apple.menuextra.battery ShowPercent: Legacy battery percentage setting.
CURRENT_BATTERY_PCT=$(defaults read com.apple.menuextra.battery ShowPercent 2>/dev/null || echo "")
if [ "$CURRENT_BATTERY_PCT" != "$LEGACY_BATTERY_PCT" ]; then
  grn_print "Set legacy battery menu extra ShowPercent to $LEGACY_BATTERY_PCT..."
  defaults write com.apple.menuextra.battery ShowPercent -string "$LEGACY_BATTERY_PCT" || red_print "Failed to set ShowPercent"
  NEEDS_UI_RESTART=true
else
  yel_print "Legacy battery ShowPercent already $LEGACY_BATTERY_PCT. Skipping..."
fi

# com.apple.controlcenter BatteryShowInMenuBar: Modern macOS setting to show battery icon in the menu bar.
# Values: true (1), false (0)
TARGET_CC_BATTERY_BAR=true
CURRENT_CC_BATTERY_BAR=$(defaults -currentHost read com.apple.controlcenter BatteryShowInMenuBar 2>/dev/null || echo "")
if [ "$CURRENT_CC_BATTERY_BAR" != "1" ] && [ "$CURRENT_CC_BATTERY_BAR" != "true" ] && [ "$CURRENT_CC_BATTERY_BAR" != "YES" ]; then
  grn_print "Set Control Center BatteryShowInMenuBar to $TARGET_CC_BATTERY_BAR..."
  defaults -currentHost write com.apple.controlcenter BatteryShowInMenuBar -bool "$TARGET_CC_BATTERY_BAR" || red_print "Failed to set BatteryShowInMenuBar"
  NEEDS_UI_RESTART=true
else
  yel_print "BatteryShowInMenuBar already $TARGET_CC_BATTERY_BAR. Skipping..."
fi

# com.apple.controlcenter BatteryShowPercentage: Modern macOS setting to show battery percentage next to the icon.
# We normalize the read value because macOS can sometimes return "1", "true", or "YES"
# depending on the OS version and how it was last written. We map all truthy values
# to a standard `true` or `false` boolean string to compare it reliably against our
# unified $TARGET_SHOW_BATTERY_PERCENTAGE variable.
CURRENT_CC_BATTERY_PCT=$(defaults -currentHost read com.apple.controlcenter BatteryShowPercentage 2>/dev/null || echo "")

if [ "$CURRENT_CC_BATTERY_PCT" = "1" ] || [ "$CURRENT_CC_BATTERY_PCT" = "true" ] || [ "$CURRENT_CC_BATTERY_PCT" = "YES" ]; then
  ACTUAL_CC_BATTERY_PCT=true
else
  ACTUAL_CC_BATTERY_PCT=false
fi

if [ "$ACTUAL_CC_BATTERY_PCT" != "$TARGET_SHOW_BATTERY_PERCENTAGE" ]; then
  grn_print "Set Control Center BatteryShowPercentage to $TARGET_SHOW_BATTERY_PERCENTAGE..."
  defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool "$TARGET_SHOW_BATTERY_PERCENTAGE" || red_print "Failed to set BatteryShowPercentage"
  NEEDS_UI_RESTART=true
else
  yel_print "BatteryShowPercentage already $TARGET_SHOW_BATTERY_PERCENTAGE. Skipping..."
fi

# com.apple.controlcenter Sound: Configures the visibility of the Sound icon in the menu bar.
# Values: 18 (Always display icon in menu bar), 24 (Hide icon from menu bar)
# Docs: See Control Center modules configuration (https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/defaults/controlcenter.nix)
TARGET_SOUND=18
CURRENT_SOUND=$(defaults -currentHost read com.apple.controlcenter Sound 2>/dev/null || echo "")
if [ "$CURRENT_SOUND" != "$TARGET_SOUND" ]; then
  grn_print "Set Control Center Sound to $TARGET_SOUND..."
  defaults -currentHost write com.apple.controlcenter Sound -int "$TARGET_SOUND" || red_print "Failed to set Control Center Sound"
  NEEDS_UI_RESTART=true
else
  yel_print "Control Center Sound already $TARGET_SOUND. Skipping..."
fi

if [ "$NEEDS_UI_RESTART" = true ]; then
  blue_pprint "Applying changes by running killall SystemUIServer and ControlCenter..."
  killall SystemUIServer || red_print "Failed to kill SystemUIServer"
  killall ControlCenter || red_print "Failed to kill ControlCenter"
fi
