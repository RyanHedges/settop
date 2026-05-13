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

# ---- Configure Dock Applications ----
# We use dockutil (https://github.com/kcrawford/dockutil) to idempotently manage
# the applications pinned to the Dock. Apple's native defaults are too brittle for this.
# Finder and Trash are managed by macOS inherently and cannot be removed, so this
# list defines everything in between them.

TARGET_APPS=(
  "/Applications/Firefox.app"
  "/System/Applications/Calendar.app"
  "/System/Applications/Mail.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Reminders.app"
  "/Applications/NotePlan.app"
  "/Applications/Zed.app"
  "/Applications/Ghostty.app"
  "/Applications/Sublime Merge.app"
  "/Applications/Spotify.app"
  "/System/Applications/iPhone Mirroring.app"
  "/Applications/Claude.app"
)

# Extract labels of target apps for comparison
TARGET_LABELS=()
for app_path in "${TARGET_APPS[@]}"; do
  TARGET_LABELS+=("$(basename "$app_path" .app)")
done

# Pass 1: Removals
# Read all current apps in the Dock
CURRENT_DOCK_APPS=$(dockutil --list | awk -F'\t' '{if ($3 == "persistentApps") print $1}')

while IFS= read -r app_label; do
  # Skip empty lines
  [ -z "$app_label" ] && continue
  
  found=false
  for target_label in "${TARGET_LABELS[@]}"; do
    if [ "$app_label" = "$target_label" ]; then
      found=true
      break
    fi
  done
  
  if [ "$found" = false ]; then
    grn_print "Removing '$app_label' from Dock..."
    dockutil --remove "$app_label" --no-restart >/dev/null 2>&1 || true
    NEEDS_DOCK_RESTART=true
  fi
done <<< "$CURRENT_DOCK_APPS"

# Pass 2: Additions & Ordering
# We iterate through our target list, using index for exact ordering.
for i in "${!TARGET_APPS[@]}"; do
  app_path="${TARGET_APPS[$i]}"
  app_label=$(basename "$app_path" .app)
  
  # Check if app is managed by Setapp instead of its primary location
  if [ ! -e "$app_path" ] && [ -d "/Applications/Setapp/$app_label.app" ]; then
    app_path="/Applications/Setapp/$app_label.app"
  fi
  
  if [ ! -e "$app_path" ]; then
    red_print "App '$app_label' not found on system at $app_path. Skipping..."
    continue
  fi

  # dockutil uses 1-based indexing for --position, and it does not count Finder.
  # So our 0th app is position 1, 1st is 2, etc.
  target_position=$((i + 1))
  
  find_output=$(dockutil --find "$app_label" 2>/dev/null || echo "not found")
  if ! echo "$find_output" | grep -q "persistent-apps"; then
    grn_print "Adding '$app_label' to Dock at position $target_position..."
    dockutil --add "$app_path" --position "$target_position" --no-restart >/dev/null 2>&1
    NEEDS_DOCK_RESTART=true
  else
    # App IS in the persistent dock. Check if it's in the correct slot.
    current_position=$(echo "$find_output" | grep -oE 'slot [0-9]+' | awk '{print $2}')
    
    if [ "$current_position" != "$target_position" ]; then
      grn_print "Moving '$app_label' from position $current_position to position $target_position..."
      dockutil --move "$app_label" --position "$target_position" --no-restart >/dev/null 2>&1
      NEEDS_DOCK_RESTART=true
    else
      yel_print "'$app_label' already in correct position ($target_position). Skipping..."
    fi
  fi
done

# NSGlobalDomain AppleActionOnDoubleClick: Action when double-clicking a window title bar.
# Values: "None", "Minimize", "Maximize", "Fill"
# "Fill" expands the window to fill the screen as a regular window (not full-screen mode).
# Docs: System Settings > Desktop & Dock > Double-click a window's title bar to
TARGET_DOUBLE_CLICK="Fill"
CURRENT_DOUBLE_CLICK=$(defaults read NSGlobalDomain AppleActionOnDoubleClick 2>/dev/null || echo "")
if [ "$CURRENT_DOUBLE_CLICK" != "$TARGET_DOUBLE_CLICK" ]; then
  grn_print "Set double-click title bar action to $TARGET_DOUBLE_CLICK..."
  defaults write NSGlobalDomain AppleActionOnDoubleClick -string "$TARGET_DOUBLE_CLICK" || red_print "Failed to set AppleActionOnDoubleClick"
  NEEDS_DOCK_RESTART=true
else
  yel_print "AppleActionOnDoubleClick already $TARGET_DOUBLE_CLICK. Skipping..."
fi

if [ "$NEEDS_DOCK_RESTART" = true ]; then
  blue_pprint "Applying Dock changes by running killall Dock..."
  killall Dock || red_print "Failed to kill Dock"
fi
