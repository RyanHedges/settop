#!/bin/sh
pprint() {
  local msg="$1"; shift
  printf "\n$msg\n"
}

grnprint() {
  local msg="$1"; shift
  printf "\e[92m$msg\e[0m\n"
}

set -e

pprint ""
grnprint "============================================================"
grnprint "==      ===        ==        ==        ====    ====       =="
grnprint "=  ====  ==  ===========  ========  ======  ==  ===  ====  ="
grnprint "=  ====  ==  ===========  ========  =====  ====  ==  ====  ="
grnprint "==  =======  ===========  ========  =====  ====  ==  ====  ="
grnprint "====  =====      =======  ========  =====  ====  ==       =="
grnprint "======  ===  ===========  ========  =====  ====  ==  ======="
grnprint "=  ====  ==  ===========  ========  =====  ====  ==  ======="
grnprint "=  ====  ==  ===========  ========  ======  ==  ===  ======="
grnprint "==      ===        =====  ========  =======    ====  ======="
grnprint "============================================================"

# ---- Install Homebrew ----
# --------------------------
pprint "Checking if Homebrew needs to be installed..."
if ! command -v brew >/dev/null; then
  grnprint "Installing Homebrew..."
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
  grnprint "Homebrew already installed"
fi

# ---- Brew the things ----
# -------------------------
pprint "Installing Hombrew packages"

grnprint "Updating Homebrew..."
brew update

if ! command -v brew ls --version git >/dev/null; then
grnprint "Installing git..."
brew install git
fi

grnprint "Installing rbenv..."
brew install rbenv

if ! command -v brew ls --version ruby-build >/dev/null; then
grnprint "Installing ruby-build..."
brew install ruby-build
fi

grnprint "Installing Zsh..."
brew install zsh

if ! command -v brew ls --version vim >/dev/null; then
grnprint "Installing Vim..."
brew install vim --override-system-vi
fi

# ---- Install Dotfiles ----
# --------------------------
pprint "Checking for ~/.dotfiles..."
if [ ! -d ~/.dotfiles ]; then
  grnprint "Cloning RyanHedges/dotfiles into ~/.dotfiles"
  git clone git@github.com:RyanHedges/dotfiles.git ~/.dotfiles
else
  grnprint "Using existing ~/.dotfiles"
fi

pprint "Creating links to ~/.dotfiles..."
~/.dotfiles/bin/install

# ---- Set shell to Zsh ----
# --------------------------
pprint "Checking if zsh is added to /etc/shells"
if ! grep -Fq "$(which zsh)" "/etc/shells"; then
  grnprint "Adding $(which zsh) to /etc/shells"
  sudo sh -c "echo '$(which zsh)' >> /etc/shells"
else
  grnprint "zsh already in /etc/shells"
fi

case "$SHELL" in
  */zsh) : ;;
  *)
    chsh -s "$(which zsh)"
    ;;
esac

# ---- Directory Structure ----
# -----------------------------
pprint "Setting up directory structure..."
if [ ! -e "$HOME/projects" ]
  then
    grnprint "Creating projects directory"
    mkdir $HOME/projects
fi

# ---- Setup Ruby ----
# --------------------
find_ruby_version() {
  rbenv install -l | grep -v - | tail -1 | sed -e 's/^ *//'
}
ruby_version="$(find_ruby_version)"

pprint "Setting up ruby..."
eval "$(rbenv init -)"
if ! rbenv versions | grep -Fq "$ruby_version"; then
  grnprint "Installing ruby version $($ruby_version)..."
  rbenv install "$ruby_version"
else
  grnprint "Ruby version $ruby_version already installed"
fi

grnprint "Setting global ruby version to $ruby_version"
rbenv global "$ruby_version"

grnprint "Setting shell ruby version to $ruby_version"
rbenv shell "$ruby_version"

# ---- Install Gems ----
# ----------------------
gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    grnprint "Updating $@"
    gem update "$@"
  else
    grnprint "Installing $@"
    gem install "$@"
    rbenv rehash
  fi
}

pprint "Installing Gems..."
grnprint "Updating RubyGems system software"
gem update --system

gem_install_or_update 'bundler'

# ---- Finder Setup ----
# ----------------------
pprint "Setting up Finder..."
grnprint "Showing hidden files"
defaults write com.apple.finder AppleShowAllFiles YES
killall Finder

pprint ""
grnprint "Your system is now settop"
