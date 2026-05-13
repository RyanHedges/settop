#!/bin/bash

set -e

# Robustly resolve the symlink to find the true project root
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"; SOURCE="$(readlink "$SOURCE")"; [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"; done
SETTOP_ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"

source "$SETTOP_ROOT/import.sh"

import "colors.sh"
import "state.sh"
import "configure_app.sh"

# https://budavariam.github.io/asciiart-text/
# DOS Rebel
pprint ""
grn_print "  █████████  ██████████ ███████████ ███████████    ███████    ███████████ "
grn_print " ███░░░░░███░░███░░░░░█░█░░░███░░░█░█░░░███░░░█  ███░░░░░███ ░░███░░░░░███"
grn_print "░███    ░░░  ░███  █ ░ ░   ░███  ░ ░   ░███  ░  ███     ░░███ ░███    ░███"
grn_print "░░█████████  ░██████       ░███        ░███    ░███      ░███ ░██████████ "
grn_print " ░░░░░░░░███ ░███░░█       ░███        ░███    ░███      ░███ ░███░░░░░░  "
grn_print " ███    ░███ ░███ ░   █    ░███        ░███    ░░███     ███  ░███        "
grn_print "░░█████████  ██████████    █████       █████    ░░░███████░   █████       "
grn_print " ░░░░░░░░░  ░░░░░░░░░░    ░░░░░       ░░░░░       ░░░░░░░    ░░░░░        "

# ---- Install Homebrew ----
# --------------------------
blue_pprint "Installing Homebrew..."
if ! command -v brew >/dev/null; then
  grn_print "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source ~/.zprofile
else
  yel_print "Homebrew already installed"
fi

# ---- Brew the things ----
# -------------------------
blue_pprint "Installing Hombrew packages"

grn_print "Updating Homebrew..."
brew update

brew_install() {
  local pkg="$1"; shift
  if ! brew ls --versions $pkg >/dev/null; then
    grn_print "Installing $pkg..."
    brew install $pkg
  else
    yel_print "$pkg already installed"
  fi
}

brew_install git
brew_install rbenv
brew_install ruby-build
brew_install zsh
brew_install gh
configure_app ssh
configure_app github
brew_install gifski
brew_install vim
brew_install mas
brew_install dockutil

if ! brew tap | grep -q '^drewdeponte/oss$'; then
  grn_print 'Brew tapping "drewdeponte/oss"...'
  brew tap "drewdeponte/oss" "git://git.drewdeponte.com/homebrew-oss.git"
else
  yel_print 'Brew already tapped "drewdeponte/oss"...'
fi

brew_install git-ps-rs

# ---- Install Dotfiles ----
# --------------------------
blue_pprint "Installing Dotfiles..."
grn_print "Checking for ~/.dotfiles..."
if [ ! -d ~/.dotfiles ]; then
  grn_print "Cloning RyanHedges/dotfiles into ~/.dotfiles"
  git clone git@github.com:RyanHedges/dotfiles.git ~/.dotfiles
else
  yel_print "Using existing ~/.dotfiles"
  grn_print "Pulling the latest dotfiles instead..."
  git -C ~/.dotfiles pull
fi

blue_pprint "Creating links to ~/.dotfiles..."
~/.dotfiles/bin/install

# ---- Install OpenCode CLI ----
# --------------------------------
brew_install opencode

# ---- Bootstrap Vim ----
# -----------------------
blue_pprint "Bootstrapping vim..."
grn_print "Running .dotfiles vim_strap"
source ~/.dotfiles/bin/vim_strap

# ---- Set shell to Zsh ----
# --------------------------
blue_pprint "Setup zsh..."
grn_print "Checking if zsh is added to /etc/shells"
if ! grep -Fq "$(which zsh)" "/etc/shells"; then
  grn_print "Adding $(which zsh) to /etc/shells"
  sudo sh -c "echo '$(which zsh)' >> /etc/shells"
else
  yel_print "zsh already in /etc/shells"
fi

grn_print "Ensuring shell is using zsh..."
case "$SHELL" in
  */zsh)
    yel_print "Shell already using zsh"
    ;;
  *)
    grn_print "Changing shell to zsh"
    chsh -s "$(which zsh)"
    ;;
esac

# ---- Directory Structure ----
# -----------------------------
blue_pprint "Setting up directory structure..."
if [ ! -e "$HOME/projects" ]; then
  grn_print "Creating projects directory"
  mkdir $HOME/projects
else
  yel_print "$HOME/projects already exists"
fi

# ---- Setup Ruby ----
# --------------------
find_ruby_version() {
  rbenv install -l | grep -v - | tail -1 | sed -e 's/^ *//'
}
ruby_version="$(find_ruby_version)"

blue_pprint "Setting up ruby..."
eval "$(rbenv init -)"
if ! rbenv versions | grep -Fq "$ruby_version"; then
  grn_print "Installing ruby version $($ruby_version)..."
  rbenv install "$ruby_version"
else
  yel_print "Ruby version $ruby_version already installed"
fi


current_global_version=$(rbenv global)
grn_print "global ruby: $current_global_version vs. latest ruby: $ruby_version"
if [[ "$current_global_version" != "$ruby_version" ]]; then
  grn_print "Setting global ruby version to $ruby_version"
  rbenv global "$ruby_version"
else
  yel_print "Ruby $ruby_version already set to global ruby"
fi

current_shell_version=$(rbenv version-name)
grn_print "shell version: $current_shell_version vs. latest ruby: $ruby_version"
if [[ "$current_shell_version" != "$ruby_version" ]]; then
  grn_print "Setting shell ruby version to $ruby_version"
  rbenv shell "$ruby_version"
else
  yel_print "Ruby $ruby_version already set to current shell version"
fi

# ---- Install Gems ----
# ----------------------
gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    grn_print "Updating $@..."
    gem update "$@"
  else
    grn_print "Installing $@..."
    gem install "$@"
    rbenv rehash
  fi
}

blue_pprint "Installing Gems..."
grn_print "Updating RubyGems system software through gem update --system..."
gem update --system

gem_install_or_update 'bundler'

# ---- Font Setup ----
# --------------------
blue_pprint "Installing Fonts..."
  if [ ! -f ~/Library/Fonts/mononoki-Regular.ttf ]; then
    grn_print "Installing Mononoki font"
    curl -o ~/Downloads/mononoki.zip -Lk https://raw.githubusercontent.com/madmalik/mononoki/master/export/mononoki.zip
    unzip -j ~/Downloads/mononoki.zip -d ~/Library/Fonts
    rm ~/Downloads/mononoki.zip
  else
    yel_print "Mononoki font already installed"
  fi

# ---- Installing NVM ----
# ------------------------

blue_pprint "Installing NVM..."
if [ ! -d "$HOME/.nvm" ]; then
  grn_print "Cloning nvm into ~/.nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

  grn_print 'Loading nvm...'
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  grn_print 'Installing node...'
  nvm install node
else
  yel_print "Using existing $HOME/.nvm"
fi

brew_install_cask() {
  local pkg="$1"; shift
  if ! brew ls --cask --versions $pkg >/dev/null; then
    grn_print "Installing $pkg..."
    brew install --cask $pkg
  else
    yel_print "$pkg already installed. Skipping..."
  fi
}

# ---- Installing Nerd Font ----
# ------------------------------
blue_pprint "Installing Nerd Font..."
brew_install_cask font-hack-nerd-font

# ---- Installing Zed ----
# ------------------------
blue_pprint "Installing Zed..."
brew_install_cask zed

# ---- Installing Setapp ----
# ---------------------------
blue_pprint "Installing Setapp..."
brew_install_cask setapp

# ---- Installing Firefox ----
# ----------------------------
blue_pprint "Installing Firefox..."
brew_install_cask firefox

# ---- Installing Google Chrome ----
# ----------------------------------
blue_pprint "Installing Google Chrome..."
brew_install_cask google-chrome

# ---- Installing Slack ----
# --------------------------
blue_pprint "Installing Slack..."
brew_install_cask slack

# ---- Installing Zoom ----
# -------------------------
blue_pprint "Installing Zoom..."
brew_install_cask zoom

# ---- Installing 1Password ----
# ------------------------------
blue_pprint "Installing 1Password..."
brew_install_cask 1password
brew_install_cask 1password-cli

# ---- Installing Postico ----
# ----------------------------
blue_pprint "Installing Postico..."
brew_install_cask postico

# ---- Installing Spotify ----
# ----------------------------
blue_pprint "Installing Spotify..."
brew_install_cask spotify

# ---- Installing Tuple ----
# --------------------------
blue_pprint "Installing Tuple..."
brew_install_cask tuple

# ---- Installing Rectangle ----
# ------------------------------
blue_pprint "Installing Rectangle..."
brew_install_cask rectangle
configure_app rectangle

# ---- Installing Sublime Merge ----
# ----------------------------------
blue_pprint "Installing Sublime Merge..."
brew_install_cask sublime-merge
configure_app sublime-merge

# ---- Installing Claude ----
# ----------------------------
blue_pprint "Installing Claude..."
brew_install_cask claude

# ---- Installing Maccy ----
# --------------------------
blue_pprint "Installing Maccy..."
brew_install_cask maccy

# ---- Installing Boop ----
# -------------------------
blue_pprint "Installing Boop..."
brew_install_cask boop

# ---- Installing Ghostty ----
# ----------------------------
blue_pprint "Installing Ghostty..."
brew_install_cask ghostty

# ---- Installing OpenCode Desktop ----
# -------------------------------------
blue_pprint "Installing OpenCode Desktop..."
brew_install_cask opencode-desktop

# ---- Installing XCode ----
# --------------------------
blue_pprint "Installing XCode..."
if [ -d "/Applications/Xcode.app" ]; then
  yel_print "XCode already installed. Skipping..."
else
  grn_print "XCode installing..."
  mas install 497799835
fi

# ---- Installilng Command-Line Tools ----
# ----------------------------------------
blue_pprint "Installing Command-Line Tools..."
if xcode-select -p &>/dev/null; then
  yel_print "Command-Line Tools already installed. Skipping..."
else
  grn_print "Command-Line Tools installing..."
  xcode-select --install
fi

# ---- Configure macOS defaults ----
# ----------------------------------
# These configurations may use Swift (e.g. night-shift, macos-keyboard sync agent)
# so they MUST be run after the Command-Line Tools have been installed.
configure_app macos-finder
configure_app macos-keyboard
configure_app macos-ui
configure_app macos-clock
configure_app macos-display
configure_app night-shift

# ---- Configure macOS Dock ----
# ------------------------------
# Dock configuration must run after all applications (including casks) have been
# installed so dockutil can verify they exist on disk before pinning them.
configure_app macos-dock


# ---- Finish Setup ----
# ----------------------
# https://budavariam.github.io/asciiart-text/
# DOS Rebel
blue_pprint "Your system is now settop!"
blue_pprint "  █████████  █████  █████   █████████    █████████  ██████████  █████████   █████████"
 blue_print " ███░░░░░███░░███  ░░███   ███░░░░░███  ███░░░░░███░░███░░░░░█ ███░░░░░███ ███░░░░░███"
 blue_print "░███    ░░░  ░███   ░███  ███     ░░░  ███     ░░░  ░███  █ ░ ░███    ░░░ ░███    ░░░"
 blue_print "░░█████████  ░███   ░███ ░███         ░███          ░██████   ░░█████████ ░░█████████"
 blue_print " ░░░░░░░░███ ░███   ░███ ░███         ░███          ░███░░█    ░░░░░░░░███ ░░░░░░░░███"
 blue_print " ███    ░███ ░███   ░███ ░░███     ███░░███     ███ ░███ ░   █ ███    ░███ ███    ░███"
 blue_print "░░█████████  ░░████████   ░░█████████  ░░█████████  ██████████░░█████████ ░░█████████"
 blue_print " ░░░░░░░░░    ░░░░░░░░     ░░░░░░░░░    ░░░░░░░░░  ░░░░░░░░░░  ░░░░░░░░░   ░░░░░░░░░"
pprint ""

if [ ${#REQUIRES_RESTART_REASONS[@]} -gt 0 ]; then
  pprint ""
  yel_print "⚠️  A LOGOUT OR RESTART IS REQUIRED FOR THE FOLLOWING CHANGES TO TAKE EFFECT:"
  for reason in "${REQUIRES_RESTART_REASONS[@]}"; do
    yel_print "   - $reason"
  done
  pprint ""

  read -p "$(printf '\e[33mWould you like to log out now to apply these changes? (y/N): \e[0m')" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    blue_print "Logging out..."
    osascript -e 'tell application "System Events" to log out'
  fi
fi
