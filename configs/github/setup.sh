source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring GitHub with SSH keys..."

# NOTE: This script is sourced by settop.sh. Any exit 1 here terminates the
# entire settop.sh run intentionally — a GitHub config failure is unrecoverable
# for the rest of setup (SSH keys won't be uploaded, signing won't work).

# --- 1. Ensure fallback SSH key exists (created by configs/ssh/setup.sh) ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
  yel_print "SSH key ~/.ssh/id_ed25519 not found."
  yel_print "Run settop.sh first to set up the fallback SSH key."
  exit 1
fi
grn_print "Using existing SSH key: ~/.ssh/id_ed25519"

# --- 2. Create github.conf in config.d/ (scopes key to github.com only) ---
# Note: sshCommand in gitconfig overrides this for git operations.
# This file is used for ssh command testing (e.g., ssh -T git@github.com).
GITHUB_CONF="$HOME/.ssh/config.d/github.conf"
grn_print "Writing $GITHUB_CONF (overwrites on re-run)..."
cat > "$GITHUB_CONF" << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
EOF
chmod 600 "$GITHUB_CONF"

# --- 2b. GitHub per-project gitconfig with includeIf ---
DOTFILES_GITCONFIG="$HOME/.dotfiles/git/gitconfig"

# Prompt for GitHub email
DEFAULT_GITHUB_EMAIL=$(git config --global user.email 2>/dev/null)
grn_print "Enter your GitHub email or press Enter to use [$DEFAULT_GITHUB_EMAIL]:"
read -r GITHUB_EMAIL
GITHUB_EMAIL=${GITHUB_EMAIL:-$DEFAULT_GITHUB_EMAIL}
if [ -z "$GITHUB_EMAIL" ]; then
  yel_print "GitHub email cannot be empty."
  exit 1
fi

# Prompt for GitHub project directories (space-separated, default ~/projects/ryanhedges)
grn_print "Enter GitHub project directories (space-separated, or press Enter for [$HOME/projects/ryanhedges]):"
read -r GITHUB_DIRS_INPUT
GITHUB_DIRS=${GITHUB_DIRS_INPUT:-"$HOME/projects/ryanhedges"}

GITHUB_DIR_ARRAY=()
for dir in $GITHUB_DIRS; do
  dir="${dir/#\~/$HOME}"
  if [ -d "$dir" ]; then
    dir=$(cd "$dir" && pwd)
  fi
  dir="${dir%/}/"  # trailing / required for gitdir: matching
  GITHUB_DIR_ARRAY+=("$dir")
done

# Create per-account gitconfig for GitHub
GITHUB_GITCONFIG="$HOME/.dotfiles/git/gitconfig-github"
grn_print "Writing $GITHUB_GITCONFIG (overwrites on re-run)..."
cat > "$GITHUB_GITCONFIG" << EOF
[user]
    email = $GITHUB_EMAIL

[core]
    # sshCommand is required for multi-account support on the same host (e.g., multiple GitHub accounts).
    # SSH config (config.d/*.conf) routes by hostname only — it cannot distinguish between two accounts
    # on github.com. git's sshCommand routes by directory via the includeIf in gitconfig, ensuring
    # the correct key is used per project regardless of what the SSH agent has loaded.
    # The config.d file is still used for direct SSH testing (e.g., ssh -T git@github.com).
    sshCommand = "ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes -F /dev/null"
EOF

# Add includeIf entries for each GitHub project directory.
# The git config key format is: includeIf.gitdir:<path>.path
# git config writes the quotes around the condition automatically — do NOT
# add them in the key string or git will double-escape them, producing
# [includeIf "\"gitdir:...\"""] which is invalid and never matches.
for dir in "${GITHUB_DIR_ARRAY[@]}"; do
  INCLUDE_KEY="includeIf.gitdir:${dir}.path"
  if git config --file "$DOTFILES_GITCONFIG" --get "$INCLUDE_KEY" &>/dev/null; then
    yel_print "includeIf for $dir already exists in $DOTFILES_GITCONFIG. Skipping."
  else
    grn_print "Adding includeIf for $dir to $DOTFILES_GITCONFIG..."
    git config --file "$DOTFILES_GITCONFIG" --add "$INCLUDE_KEY" "$GITHUB_GITCONFIG"
  fi
done

# Ensure default user.email exists in main gitconfig (for repos not matching any includeIf)
if ! git config --file "$DOTFILES_GITCONFIG" user.email &>/dev/null; then
  grn_print "Enter your default git email (for repos not matching any includeIf):"
  read -r DEFAULT_EMAIL
  git config --file "$DOTFILES_GITCONFIG" user.email "$DEFAULT_EMAIL"
  grn_print "Default email set in $DOTFILES_GITCONFIG"
else
  yel_print "Default user.email already set in $DOTFILES_GITCONFIG"
fi

# --- 3. Prompt for key nickname (hostname as default) ---
DEFAULT_NICKNAME=$(scutil --get ComputerName 2>/dev/null || hostname)
grn_print "Enter a nickname for this machine's SSH keys or press Enter to use [$DEFAULT_NICKNAME]:"
read -r NICKNAME
NICKNAME=${NICKNAME:-$DEFAULT_NICKNAME}
grn_print "Using key nickname: $NICKNAME"

# --- 4. Authenticate gh CLI with required scopes ---
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

# --- 4b. Refresh token if missing SSH key management scopes ---
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

# --- 5. Add key to GitHub as AUTH type (title-based duplicate check) ---
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

# --- 6. Add key to GitHub as SIGNING type (title-based duplicate check) ---
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

# --- 7. Verify Git config (managed by dotfiles) ---
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
