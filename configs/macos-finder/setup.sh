source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"
import "state.sh"

blue_pprint "Configuring Finder..."

NEEDS_FINDER_RESTART=false

# AppleShowAllExtensions: Show all filename extensions in Finder.
# Values: true (1), false (0)
# Docs: https://macos-defaults.com/finder/appleshowallextensions.html
TARGET_SHOW_EXT=true
CURRENT_SHOW_EXT=$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_EXT" != "1" ] && [ "$CURRENT_SHOW_EXT" != "true" ] && [ "$CURRENT_SHOW_EXT" != "YES" ]; then
  grn_print "Set AppleShowAllExtensions to $TARGET_SHOW_EXT..."
  defaults write NSGlobalDomain AppleShowAllExtensions -bool "$TARGET_SHOW_EXT" || red_print "Failed to set AppleShowAllExtensions"
  NEEDS_FINDER_RESTART=true
else
  yel_print "AppleShowAllExtensions already $TARGET_SHOW_EXT. Skipping..."
fi

# FXRemoveOldTrashItems: Automatically empty the trash after 30 days.
# Values: true (1), false (0)
# Docs: https://macos-defaults.com/finder/fxremoveoldtrashitems.html
TARGET_REMOVE_TRASH=true
CURRENT_REMOVE_TRASH=$(defaults read com.apple.finder FXRemoveOldTrashItems 2>/dev/null || echo "")
if [ "$CURRENT_REMOVE_TRASH" != "1" ] && [ "$CURRENT_REMOVE_TRASH" != "true" ] && [ "$CURRENT_REMOVE_TRASH" != "YES" ]; then
  grn_print "Set FXRemoveOldTrashItems to $TARGET_REMOVE_TRASH..."
  defaults write com.apple.finder FXRemoveOldTrashItems -bool "$TARGET_REMOVE_TRASH" || red_print "Failed to set FXRemoveOldTrashItems"
  NEEDS_FINDER_RESTART=true
else
  yel_print "FXRemoveOldTrashItems already $TARGET_REMOVE_TRASH. Skipping..."
fi

# ShowPathbar: Show the path bar at the bottom of Finder windows.
# Values: true (1), false (0)
# Docs: https://macos-defaults.com/finder/showpathbar.html
TARGET_SHOW_PATHBAR=true
CURRENT_SHOW_PATHBAR=$(defaults read com.apple.finder ShowPathbar 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_PATHBAR" != "1" ] && [ "$CURRENT_SHOW_PATHBAR" != "true" ] && [ "$CURRENT_SHOW_PATHBAR" != "YES" ]; then
  grn_print "Set ShowPathbar to $TARGET_SHOW_PATHBAR..."
  defaults write com.apple.finder ShowPathbar -bool "$TARGET_SHOW_PATHBAR" || red_print "Failed to set ShowPathbar"
  NEEDS_FINDER_RESTART=true
else
  yel_print "ShowPathbar already $TARGET_SHOW_PATHBAR. Skipping..."
fi

# FXPreferredViewStyle: Set the default view style for Finder folders.
# Values: "icnv" (Icon view), "Nlsv" (List view), "clmv" (Column view), "Flwv" (Gallery view)
# Docs: https://macos-defaults.com/finder/fxpreferredviewstyle.html
TARGET_VIEW_STYLE="clmv"
CURRENT_VIEW_STYLE=$(defaults read com.apple.finder FXPreferredViewStyle 2>/dev/null || echo "")
if [ "$CURRENT_VIEW_STYLE" != "$TARGET_VIEW_STYLE" ]; then
  grn_print "Set default view style for folders to $TARGET_VIEW_STYLE..."
  defaults write com.apple.finder FXPreferredViewStyle -string "$TARGET_VIEW_STYLE" || red_print "Failed to set FXPreferredViewStyle"
  NEEDS_FINDER_RESTART=true
else
  yel_print "FXPreferredViewStyle already $TARGET_VIEW_STYLE. Skipping..."
fi

# AppleShowAllFiles: Show hidden files and folders inside Finder.
# Values: true (1), false (0)
# Docs: https://macos-defaults.com/finder/appleshowallfiles.html
TARGET_SHOW_HIDDEN=true
CURRENT_SHOW_HIDDEN=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "")
if [ "$CURRENT_SHOW_HIDDEN" != "1" ] && [ "$CURRENT_SHOW_HIDDEN" != "true" ] && [ "$CURRENT_SHOW_HIDDEN" != "YES" ]; then
  grn_print "Set AppleShowAllFiles to $TARGET_SHOW_HIDDEN..."
  defaults write com.apple.finder AppleShowAllFiles -bool "$TARGET_SHOW_HIDDEN" || red_print "Failed to set AppleShowAllFiles"
  NEEDS_FINDER_RESTART=true
else
  yel_print "AppleShowAllFiles already $TARGET_SHOW_HIDDEN. Skipping..."
fi

if [ "$NEEDS_FINDER_RESTART" = true ]; then
  grn_print "Applying changes to Finder with killall..."
  killall Finder || red_print "Failed to killall Finder"
fi