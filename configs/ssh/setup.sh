source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring SSH keys (fallback/generic key)..."

# --- 1. Generate SSH key if missing (used as fallback for all hosts) ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
  grn_print "Generating new SSH key (ed25519)..."
  DEFAULT_EMAIL=$(git config --global user.email 2>/dev/null)
  grn_print "Enter the account email for your key or press Enter to use [$DEFAULT_EMAIL]:"
  read -r email
  email=${email:-$DEFAULT_EMAIL}
  grn_print "Using key email: $email"
  # Prompt for passphrase interactively (no -N flag to enforce passphrase entry)
  ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
else
  yel_print "SSH key ~/.ssh/id_ed25519 already exists"
fi

# --- 2. Set up ~/.ssh/config.d/ for modular SSH config ---
if [ ! -d ~/.ssh/config.d ]; then
  grn_print "Creating ~/.ssh/config.d/ directory..."
  mkdir -p ~/.ssh/config.d
  chmod 700 ~/.ssh/config.d
else
  yel_print "~/.ssh/config.d/ already exists"
fi

# Prepend Include directive to main ~/.ssh/config (idempotent).
# Must be at the TOP of the file — OpenSSH processes Host blocks in order and
# stops at the first match. An Include at the end would be parsed after any
# existing Host blocks, meaning included conf files would be shadowed and
# effectively ignored for hosts that already matched above.
if ! grep -qF "Include ~/.ssh/config.d/*.conf" ~/.ssh/config 2>/dev/null; then
  grn_print "Prepending Include directive to ~/.ssh/config..."
  EXISTING=$(cat ~/.ssh/config 2>/dev/null || true)
  printf 'Include ~/.ssh/config.d/*.conf\n\n%s' "$EXISTING" > ~/.ssh/config
  chmod 600 ~/.ssh/config
else
  yel_print "Include directive already in ~/.ssh/config"
fi

# Warn about old Host * block (migrated to config.d/)
if grep -q "Host \*" ~/.ssh/config 2>/dev/null; then
  yel_print "Note: Old 'Host *' block found in ~/.ssh/config."
  yel_print "Consider removing it manually since config is now in ~/.ssh/config.d/"
fi

# --- 3. Start ssh-agent and add key ---
eval "$(ssh-agent -s)" 2>/dev/null || true
if ssh-add -l 2>/dev/null | grep -q "id_ed25519"; then
  yel_print "SSH key already in agent"
else
  grn_print "Adding key to ssh-agent..."
  if ssh-add --apple-use-keychain ~/.ssh/id_ed25519; then
    grn_print "SSH key added to agent"
  else
    yel_print "Failed to add key to agent (agent may not be running)"
  fi
fi
