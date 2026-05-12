source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"
import "state.sh"

blue_pprint "Configuring Keyboard..."

# KeyRepeat: Set the speed of the key repeat rate.
# Normal minimum through the UI is 2 (30 ms). 1 is a very fast repeat (~15 ms).
# Values: 1 (15ms), 2 (30ms), 3 (45ms), etc.
# Docs: https://apple.stackexchange.com/questions/10467/how-to-increase-keyboard-key-repeat-rate-on-os-x
TARGET_KEY_REPEAT=1
CURRENT_KEY_REPEAT=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "")
if [ "$CURRENT_KEY_REPEAT" != "$TARGET_KEY_REPEAT" ]; then
  grn_print "Set key repeat rate to $TARGET_KEY_REPEAT..."
  defaults write NSGlobalDomain KeyRepeat -int "$TARGET_KEY_REPEAT" || red_print "Failed to set KeyRepeat"
  require_restart "Keyboard: Increased key repeat rate to $TARGET_KEY_REPEAT"
else
  yel_print "KeyRepeat already set to $TARGET_KEY_REPEAT. Skipping..."
fi

# InitialKeyRepeat: Set the delay until a key starts repeating.
# Normal minimum through the UI is 15 (225 ms). 10 is ~150 ms.
# Values: 15 (225ms), 10 (150ms), 25 (375ms), etc.
# Docs: https://apple.stackexchange.com/questions/10467/how-to-increase-keyboard-key-repeat-rate-on-os-x
TARGET_INITIAL_KEY_REPEAT=15
CURRENT_INITIAL_KEY_REPEAT=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "")
if [ "$CURRENT_INITIAL_KEY_REPEAT" != "$TARGET_INITIAL_KEY_REPEAT" ]; then
  grn_print "Set the delay until key repeat to $TARGET_INITIAL_KEY_REPEAT..."
  defaults write NSGlobalDomain InitialKeyRepeat -int "$TARGET_INITIAL_KEY_REPEAT" || red_print "Failed to set InitialKeyRepeat"
  require_restart "Keyboard: Decreased delay until key repeat to $TARGET_INITIAL_KEY_REPEAT"
else
  yel_print "InitialKeyRepeat already set to $TARGET_INITIAL_KEY_REPEAT. Skipping..."
fi

# ApplePressAndHoldEnabled: Enable or disable the press-and-hold popup for special characters.
# Disabling this is usually required for fast key repeat to work properly in many apps (like VSCode).
# Values: true (1), false (0)
# Docs: https://macos-defaults.com/keyboard/applepressandholdenabled.html
TARGET_PRESS_HOLD=false
CURRENT_PRESS_HOLD=$(defaults read NSGlobalDomain ApplePressAndHoldEnabled 2>/dev/null || echo "")
if [ "$CURRENT_PRESS_HOLD" != "0" ] && [ "$CURRENT_PRESS_HOLD" != "false" ] && [ "$CURRENT_PRESS_HOLD" != "NO" ]; then
  grn_print "Set ApplePressAndHoldEnabled to $TARGET_PRESS_HOLD..."
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool "$TARGET_PRESS_HOLD" || red_print "Failed to set ApplePressAndHoldEnabled"
  require_restart "Keyboard: Set ApplePressAndHoldEnabled to $TARGET_PRESS_HOLD"
else
  yel_print "ApplePressAndHoldEnabled already $TARGET_PRESS_HOLD. Skipping..."
fi
