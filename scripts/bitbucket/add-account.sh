#!/bin/bash

set -e

# https://stackoverflow.com/a/246128
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, resolve it relative to the symlink's dir
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

source "$SCRIPT_DIR/../../colors.sh"

# https://budavariam.github.io/asciiart-text/
# DOS Rebel
pprint ""
grn_print " ███████████  █████ ███████████ ███████████  █████  █████   █████████  █████   ████ ██████████ ███████████"
grn_print "░░███░░░░░███░░███ ░█░░░███░░░█░░███░░░░░███░░███  ░░███   ███░░░░░███░░███   ███░ ░░███░░░░░█░█░░░███░░░█"
grn_print " ░███    ░███ ░███ ░   ░███  ░  ░███    ░███ ░███   ░███  ███     ░░░  ░███  ███    ░███  █ ░ ░   ░███  ░ "
grn_print " ░██████████  ░███     ░███     ░██████████  ░███   ░███ ░███          ░███████     ░██████       ░███    "
grn_print " ░███░░░░░███ ░███     ░███     ░███░░░░░███ ░███   ░███ ░███          ░███░░███    ░███░░█       ░███    "
grn_print " ░███    ░███ ░███     ░███     ░███    ░███ ░███   ░███ ░░███     ███ ░███ ░░███   ░███ ░   █    ░███    "
grn_print " ███████████  █████    █████    ███████████  ░░████████   ░░█████████  █████ ░░████ ██████████    █████   "
grn_print "░░░░░░░░░░░  ░░░░░    ░░░░░    ░░░░░░░░░░░    ░░░░░░░░     ░░░░░░░░░  ░░░░░   ░░░░ ░░░░░░░░░░    ░░░░░   "
pprint ""

# ---- Pre-flight checks ----

if [ ! -e ~/.gitconfig ]; then
  yel_print "~/.gitconfig not found (dotfiles not set up)."
  yel_print "Run settop.sh first to set up dotfiles."
  exit 1
fi

for cmd in ssh-keygen git; do
  if ! command -v "$cmd" >/dev/null; then
    yel_print "$cmd not found. Install it first."
    exit 1
  fi
done

if [ ! -d ~/.ssh/config.d ]; then
  yel_print "~/.ssh/config.d/ not found."
  yel_print "Run settop.sh first to set up SSH config.d/ structure."
  exit 1
fi

# ---- Prompt for account details ----

# Alias (no default)
grn_print "Enter an alias for this Bitbucket account (e.g., prismlabs, acme):"
read -r ALIAS
if [ -z "$ALIAS" ]; then
  yel_print "Alias cannot be empty."
  exit 1
fi
if ! echo "$ALIAS" | grep -qE '^[a-z0-9-]+$'; then
  yel_print "Alias must contain only lowercase letters, numbers, and hyphens."
  exit 1
fi

# Email (default from git config)
DEFAULT_EMAIL=$(git config --global user.email 2>/dev/null)
grn_print "Enter the email for this Bitbucket account or press Enter to use [$DEFAULT_EMAIL]:"
read -r EMAIL
EMAIL=${EMAIL:-$DEFAULT_EMAIL}
if [ -z "$EMAIL" ]; then
  yel_print "Email cannot be empty."
  exit 1
fi
grn_print "Using email: $EMAIL"

# Project directory (default: ~/projects/<alias>/)
DEFAULT_DIR="$HOME/projects/$ALIAS/"
grn_print "Enter the project directory for this account or press Enter to use [$DEFAULT_DIR]:"
read -r PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-$DEFAULT_DIR}

# Expand ~ to $HOME and resolve to absolute path
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
if [ -d "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
else
  yel_print "Directory '$PROJECT_DIR' does not exist."
  yel_print "Create it first with: mkdir -p '$PROJECT_DIR'"
  exit 1
fi
# Ensure trailing slash for includeIf matching
case "$PROJECT_DIR" in
  */) ;;
  *) PROJECT_DIR="$PROJECT_DIR/" ;;
esac
grn_print "Using project directory: $PROJECT_DIR"

# ---- Generate SSH key ----

KEY_PATH="$HOME/.ssh/bitbucket_$ALIAS"
if [ -f "$KEY_PATH" ]; then
  yel_print "SSH key $KEY_PATH already exists. Skipping key generation."
else
  grn_print "Generating new SSH key for Bitbucket account '$ALIAS'..."
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH"
  chmod 600 "$KEY_PATH"
  chmod 644 "$KEY_PATH.pub"
  grn_print "SSH key generated at $KEY_PATH"
fi

# ---- Add key to ssh-agent and store passphrase in macOS Keychain ----

# Start a temporary ssh-agent to load the key into macOS Keychain.
# The agent is ephemeral — it exists only for this script run.
# --apple-use-keychain stores the passphrase persistently so your
# login shell's agent will auto-load this key on future sessions.
eval "$(ssh-agent -s)" 2>/dev/null || true
EPHEMERAL_AGENT_PID=$SSH_AGENT_PID

if ssh-add -l 2>/dev/null | grep -qF "$KEY_PATH"; then
  yel_print "SSH key already in agent (skipping ssh-add)"
else
  grn_print "Adding key to ssh-agent and macOS Keychain..."
  if ssh-add --apple-use-keychain "$KEY_PATH"; then
    grn_print "SSH key added to agent and passphrase stored in Keychain."
  else
    yel_print "Could not add key to agent. You may be prompted for your passphrase on each use."
  fi
fi

# ---- Create ~/.ssh/config.d/bitbucket-<alias>.conf ----

CONF_FILE="$HOME/.ssh/config.d/bitbucket-$ALIAS.conf"
grn_print "Writing $CONF_FILE (overwrites on re-run)..."
cat > "$CONF_FILE" << EOF
# NOTE: Multiple Bitbucket accounts will each have a conf file with 'Host bitbucket.org'.
# SSH config matches the first entry found — it cannot distinguish between accounts on
# the same hostname. Git operations use core.sshCommand (set via gitconfig includeIf) to
# select the correct key per directory. This file is primarily useful for direct SSH testing:
#   ssh -i ~/.ssh/bitbucket_${ALIAS} -o IdentitiesOnly=yes -o ConnectTimeout=10 -F /dev/null -T git@bitbucket.org
Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/bitbucket_$ALIAS
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
EOF
chmod 600 "$CONF_FILE"
grn_print "SSH config written to $CONF_FILE"

# ---- Create ~/.dotfiles/git/gitconfig-<alias> ----

GITCONFIG_FILE="$HOME/.dotfiles/git/gitconfig-$ALIAS"
grn_print "Writing $GITCONFIG_FILE (overwrites on re-run)..."
cat > "$GITCONFIG_FILE" << EOF
[user]
    email = $EMAIL

[core]
    # sshCommand is required for multi-account support on the same host (e.g., multiple Bitbucket accounts).
    # SSH config (config.d/*.conf) routes by hostname only — it cannot distinguish between two accounts
    # on bitbucket.org. git's sshCommand routes by directory via the includeIf in gitconfig, ensuring
    # the correct key is used per project regardless of what the SSH agent has loaded.
    # The config.d file is still used for direct SSH testing (e.g., ssh -T git@bitbucket.org).
    sshCommand = "ssh -i ~/.ssh/bitbucket_$ALIAS -o IdentitiesOnly=yes -F /dev/null"
EOF
grn_print "Per-account gitconfig written to $GITCONFIG_FILE"

# ---- Add includeIf to ~/.dotfiles/git/gitconfig (idempotent) ----

DOTFILES_GITCONFIG="$HOME/.dotfiles/git/gitconfig"
# The git config key format is: includeIf.gitdir:<path>.path
# git config writes the quotes around the condition automatically — do NOT
# add them in the key string or git will double-escape them, producing
# [includeIf "\"gitdir:...\"""] which is invalid and never matches.
# Absolute path is required — git does not expand ~ in gitdir conditions.
INCLUDE_KEY="includeIf.gitdir:${PROJECT_DIR}.path"
if git config --file "$DOTFILES_GITCONFIG" --get "$INCLUDE_KEY" &>/dev/null; then
  yel_print "includeIf for $PROJECT_DIR already exists in $DOTFILES_GITCONFIG. Skipping."
else
  grn_print "Adding includeIf to $DOTFILES_GITCONFIG..."
  git config --file "$DOTFILES_GITCONFIG" --add "$INCLUDE_KEY" "$GITCONFIG_FILE"
  grn_print "includeIf added."
fi

# ---- Print public key and upload instructions ----

pprint ""
blue_pprint "=== SSH Public Key (copy and upload to Bitbucket) ==="
pprint ""
cat "$KEY_PATH.pub"
pprint ""
blue_pprint "Upload URL: https://bitbucket.org/account/settings/ssh-keys/"
blue_pprint "1. Go to the URL above"
blue_pprint "2. Click 'Add key'"
blue_pprint "3. Paste the public key shown above"
blue_pprint "4. Save the key"
pprint ""

# ---- Verification ----

grn_print "After uploading the key, press Enter to verify..."
read -r

grn_print "Verifying SSH connection to Bitbucket..."
# ConnectTimeout prevents the script from hanging indefinitely if Bitbucket is
# unreachable or the connection stalls. || true because Bitbucket exits with code
# 1 even on a successful auth — we check stdout for "logged in as" instead.
OUTPUT=$(ssh -i "$KEY_PATH" -o IdentitiesOnly=yes -o ConnectTimeout=10 -F /dev/null -T git@bitbucket.org 2>&1) || true

if echo "$OUTPUT" | grep -qE "logged in as|authenticated via ssh key"; then
  grn_print "✓ Successfully authenticated to Bitbucket!"
  echo "$OUTPUT"
else
  yel_print "✗ Verification failed or key not yet uploaded."
  yel_print "Output: $OUTPUT"
  yel_print ""
  yel_print "Manual verification command:"
  yel_print "  ssh -i $KEY_PATH -o IdentitiesOnly=yes -o ConnectTimeout=10 -F /dev/null -T git@bitbucket.org"
  yel_print ""
  yel_print "If the output says 'authenticated via ssh key', the key is working."
fi

# Clean up the ephemeral agent started at the top of this script.
# The Keychain entry persists — your login shell's agent will auto-load
# this key from Keychain on future sessions.
[ -n "$EPHEMERAL_AGENT_PID" ] && kill "$EPHEMERAL_AGENT_PID" 2>/dev/null || true

pprint ""
grn_print "Setup complete for Bitbucket account '$ALIAS'."
grn_print "Repos cloned inside $PROJECT_DIR will use this account automatically."
