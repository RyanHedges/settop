# macOS Keyboard Configuration

This directory configures macOS keyboard preferences.

## The "Split-Brain" Architecture

Remapping keys on macOS programmatically is complex because of how the OS handles keyboard preferences vs. low-level hardware mappings. We use a dual-system approach to ensure reliability and sync.

### 1. `setup.sh` (System Settings / `.GlobalPreferences.plist`)
macOS System Settings store modifier key mappings (like Caps Lock -> Control) in `~/Library/Preferences/ByHost/.GlobalPreferences.*.plist`.
- **Pro:** This is the official OS configuration and updating it makes the macOS UI correctly reflect the mapped key.
- **Con:** It is tied to a specific hardware ID (Vendor ID + Product ID). It works perfectly for your built-in keyboard, but if you plug in a brand new external keyboard, it will not have the mapping until you configure it.

`setup.sh` detects the built-in keyboard and mutates this plist directly using `PlistBuddy` to ensure the core hardware is mapped correctly and the UI acts as a Source of Truth.

### 2. LaunchAgent & `hidutil` (Global IOKit mapping)
To ensure **all** external keyboards automatically inherit the UI setting when plugged in, we use `hidutil`.
- **Pro:** Intercepts key events globally at the IOKit driver level for *all* keyboards. No hardware IDs needed.
- **Con:** Resets on reboot and ignores the macOS System Settings UI.

### How it works together
1. When you run `setup.sh`, it configures the internal keyboard in `.GlobalPreferences` (the UI).
2. It then loads a persistent `LaunchAgent` (symlinked from `~/.dotfiles/launch-agents/com.local.KeyRemapping.plist`).
3. This LaunchAgent watches the `~/Library/Preferences/ByHost/` directory.
4. Whenever you change a modifier key in the UI (or `setup.sh` modifies the plist), the LaunchAgent instantly fires `~/.dotfiles/bin/sync_modifiers`.
5. `sync_modifiers` reads the UI preference and applies it globally via `hidutil`.

This ensures external keyboards match the System Settings UI automatically.

### Troubleshooting
If Caps Lock isn't mapping to Control:
1. **Check System Settings:** Go to System Settings -> Keyboard -> Keyboard Shortcuts -> Modifier Keys. Is Caps Lock set to Control? If not, change it. The LaunchAgent should instantly catch the change.
2. **Check the global `hidutil` mapping:**
   Run: `hidutil property --get "UserKeyMapping"`
   If Caps Lock is mapped to Control, you should see `HIDKeyboardModifierMappingSrc = 30064771129` and `Dst = 30064771296`.
3. **Check the LaunchAgent logs:**
   If the UI says Control, but `hidutil` doesn't show it, check the sync script logs:
   `cat /tmp/com.local.KeyRemapping.log`
   `cat /tmp/com.local.KeyRemapping.err`
4. **Is the LaunchAgent running?**
   Run: `launchctl list | grep com.local.KeyRemapping`
   If it's not there, load it manually:
   `launchctl load ~/Library/LaunchAgents/com.local.KeyRemapping.plist`