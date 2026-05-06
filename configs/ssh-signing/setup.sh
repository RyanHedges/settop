blue_pprint "Configuring SSH keys and commit signing..."

# --- 1. Generate SSH key if missing (merged from settop_ssh.sh) ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
  grn_print "Generating new SSH key (ed25519)..."
  # Get email from git config if available, else prompt
  email=$(git config --global user.email 2>/dev/null)
  if [ -z "$email" ]; then
    echo "Enter the GitHub account email for your key:"
    read -r email
  fi
  # Prompt for passphrase interactively (no -N flag to enforce passphrase entry)
  ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
else
  yel_print "SSH key ~/.ssh/id_ed25519 already exists"
fi

# --- 2. Configure ~/.ssh/config (merged from settop_ssh.sh) ---
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

# --- 4. Prompt for key nickname (hostname as default) ---
DEFAULT_NICKNAME=$(scutil --get ComputerName 2>/dev/null || hostname)
grn_print "Enter a nickname for this machine's SSH keys or press Enter to use [$DEFAULT_NICKNAME]:"
read -r NICKNAME
NICKNAME=${NICKNAME:-$DEFAULT_NICKNAME}
grn_print "Using key nickname: $NICKNAME"

# --- 5. Authenticate gh CLI with required scopes ---
REQUIRED_SCOPES="admin:public_key,admin:ssh_signing_key"
if ! gh auth status &>/dev/null; then
  yel_print "════════════════════════════════════════════════════"
  yel_print "  ⚠ ACTION REQUIRED: Authenticate gh CLI"
  yel_print "    A browser window will open. Follow prompts to"
  yel_print "    authenticate to GitHub."
  yel_print "════════════════════════════════════════════════════"
  if ! gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --scopes "$REQUIRED_SCOPES"; then
    yel_print "gh auth login failed. No further GitHub operations will work."
    yel_print "SSH keys will not be uploaded to GitHub and commits will not show as Verified."
    exit 1
  fi
else
  grn_print "gh CLI already authenticated"
fi

# --- 5b. Refresh token if missing SSH key management scopes ---
AUTH_STATUS=$(gh auth status 2>&1)
MISSING_SCOPES=""
for scope in admin:public_key admin:ssh_signing_key; do
  if ! echo "$AUTH_STATUS" | grep -q "$scope"; then
    MISSING_SCOPES="${MISSING_SCOPES:+$MISSING_SCOPES,}$scope"
  fi
done
if [ -n "$MISSING_SCOPES" ]; then
  grn_print "Missing scope(s): $MISSING_SCOPES. Refreshing token..."
  if ! gh auth refresh -h github.com -s "$MISSING_SCOPES"; then
    yel_print "Failed to refresh gh token with required scopes."
    yel_print "SSH keys will not be uploaded to GitHub and commits will not show as Verified."
    exit 1
  fi
  grn_print "Token refreshed with $MISSING_SCOPES scope(s)"
fi

# --- 6. Add key to GitHub as AUTH type (title-based duplicate check) ---
AUTH_TITLE="auth-$NICKNAME"
if gh ssh-key list 2>/dev/null | grep -q "$AUTH_TITLE"; then
  yel_print "Authentication key '$AUTH_TITLE' already on GitHub, skipping"
else
  grn_print "Adding SSH key to GitHub as authentication key (title: $AUTH_TITLE)..."
  if ! gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication --title "$AUTH_TITLE"; then
    yel_print "Failed to add authentication key to GitHub"
    exit 1
  fi
fi

# --- 7. Add key to GitHub as SIGNING type (title-based duplicate check) ---
SIGN_TITLE="signing-$NICKNAME"
if gh ssh-key list 2>/dev/null | grep -q "$SIGN_TITLE"; then
  yel_print "Signing key '$SIGN_TITLE' already on GitHub, skipping"
else
  grn_print "Adding SSH key to GitHub as signing key (title: $SIGN_TITLE)..."
  if ! gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$SIGN_TITLE"; then
    yel_print "Failed to add signing key to GitHub"
    exit 1
  fi
fi

# --- 8. Verify Git config (managed by dotfiles) ---
grn_print "Git signing config:"
if [ -d ~/.dotfiles ] && [ -L ~/.gitconfig ]; then
  grn_print "  ~/.gitconfig -> $(readlink ~/.gitconfig)"
  GPG_FORMAT=$(git config --global gpg.format 2>/dev/null)
  SIGNING_KEY=$(git config --global user.signingkey 2>/dev/null)
  COMMIT_SIGN=$(git config --global commit.gpgsign 2>/dev/null)
  if [ -n "$GPG_FORMAT" ] && [ -n "$SIGNING_KEY" ] && [ -n "$COMMIT_SIGN" ]; then
    grn_print "  Active signing config:"
    grn_print "    - gpg.format=$GPG_FORMAT"
    grn_print "    - user.signingkey=$SIGNING_KEY"
    grn_print "    - commit.gpgsign=$COMMIT_SIGN"
  else
    yel_print "  Signing config incomplete, check ~/.dotfiles/git/gitconfig"
  fi
elif [ -d ~/.dotfiles ]; then
  yel_print "  ~/.dotfiles exists but ~/.gitconfig is not linked yet"
  yel_print "  Run ~/.dotfiles/bin/install to set up git config"
else
  yel_print "  ~/.dotfiles not yet cloned - signing config will be set up when settop.sh continues"
fi
grn_print "Commits will be signed and show as Verified on GitHub once pushed."
