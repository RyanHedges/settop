source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring menu bar clock..."

NEEDS_CLOCK_RESTART=false

# Menu Bar Clock Settings
# All keys live in com.apple.menuextra.clock.
# Changes are applied by restarting SystemUIServer and ControlCenter.
# Docs: System Settings > Control Center > Clock Options...
#
# defaults read returns 1/0 for boolean plist types on modern macOS (Big Sur+).
# No multi-value normalization needed — System Settings and this script both
# write these keys with -bool/-int, so the read value is always 1, 0, or absent.

# ShowDate: Always show the date next to the clock.
# Values: 0=when space allows, 1=always, 2=never
CURRENT_SHOW_DATE=$(defaults read com.apple.menuextra.clock ShowDate 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_DATE" != "1" ]; then
  grn_print "Set clock ShowDate to 1 (always)..."
  defaults write com.apple.menuextra.clock ShowDate -int 1 || red_print "Failed to set clock ShowDate"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock ShowDate already 1. Skipping..."
fi

# ShowDayOfWeek: Show abbreviated day of week (Mon, Tue, etc.) next to the date.
CURRENT_SHOW_DAY_OF_WEEK=$(defaults read com.apple.menuextra.clock ShowDayOfWeek 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_DAY_OF_WEEK" != "1" ]; then
  grn_print "Set clock ShowDayOfWeek to true..."
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true || red_print "Failed to set clock ShowDayOfWeek"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock ShowDayOfWeek already true. Skipping..."
fi

# IsAnalog: Use a digital clock face rather than an analog one.
CURRENT_IS_ANALOG=$(defaults read com.apple.menuextra.clock IsAnalog 2>/dev/null || echo "")
if [ "$CURRENT_IS_ANALOG" != "0" ]; then
  grn_print "Set clock IsAnalog to false..."
  defaults write com.apple.menuextra.clock IsAnalog -bool false || red_print "Failed to set clock IsAnalog"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock IsAnalog already false. Skipping..."
fi

# ShowAMPM: Show AM/PM suffix after the time.
CURRENT_SHOW_AMPM=$(defaults read com.apple.menuextra.clock ShowAMPM 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_AMPM" != "1" ]; then
  grn_print "Set clock ShowAMPM to true..."
  defaults write com.apple.menuextra.clock ShowAMPM -bool true || red_print "Failed to set clock ShowAMPM"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock ShowAMPM already true. Skipping..."
fi

# FlashDateSeparators: Blink the : separators each second.
CURRENT_FLASH_DATE_SEPARATORS=$(defaults read com.apple.menuextra.clock FlashDateSeparators 2>/dev/null || echo "")
if [ "$CURRENT_FLASH_DATE_SEPARATORS" != "0" ]; then
  grn_print "Set clock FlashDateSeparators to false..."
  defaults write com.apple.menuextra.clock FlashDateSeparators -bool false || red_print "Failed to set clock FlashDateSeparators"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock FlashDateSeparators already false. Skipping..."
fi

# ShowSeconds: Show HH:MM:SS instead of HH:MM.
CURRENT_SHOW_SECONDS=$(defaults read com.apple.menuextra.clock ShowSeconds 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_SECONDS" != "1" ]; then
  grn_print "Set clock ShowSeconds to true..."
  defaults write com.apple.menuextra.clock ShowSeconds -bool true || red_print "Failed to set clock ShowSeconds"
  NEEDS_CLOCK_RESTART=true
else
  yel_print "Clock ShowSeconds already true. Skipping..."
fi

if [ "$NEEDS_CLOCK_RESTART" = true ]; then
  blue_pprint "Applying changes by running killall SystemUIServer and ControlCenter..."
  killall SystemUIServer || red_print "Failed to kill SystemUIServer"
  killall ControlCenter || red_print "Failed to kill ControlCenter"
fi
