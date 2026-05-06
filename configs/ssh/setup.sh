blue_pprint "Configuring SSH keys..."

# --- 1. Generate SSH key if missing ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
  grn_print "Generating new SSH key (ed25519)..."
  DEFAULT_EMAIL=$(git config --global user.email 2>/dev/null)
  grn_print "Enter the GitHub account email for your key or press Enter to use [$DEFAULT_EMAIL]:"
  read -r email
  email=${email:-$DEFAULT_EMAIL}
  grn_print "Using key email: $email"
  # Prompt for passphrase interactively (no -N flag to enforce passphrase entry)
  ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
else
  yel_print "SSH key ~/.ssh/id_ed25519 already exists"
fi

# --- 2. Configure ~/.ssh/config ---
if ! grep -q "IdentityFile ~/.ssh/id_ed25519" ~/.ssh/config 2>/dev/null; then
  grn_print "Updating ~/.ssh/config..."
  cat >> ~/.ssh/config << EOF
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
else
  yel_print "~/.ssh/config already configured"
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
