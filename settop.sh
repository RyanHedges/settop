#!/bin/sh
pprint() {
  local msg="$1"; shift
  printf "\n$msg\n"
}

grn_print() {
  local msg="$1"; shift
  printf "\e[32m$msg\e[0m\n"
}

yel_print() {
  local msg="$1"; shift
  printf "\e[33m$msg\e[0m\n"
}

blue_pprint() {
  local msg="$1"; shift
  printf "\n\e[34m$msg\e[0m\n"
}

set -e

pprint ""
grn_print "============================================================"
grn_print "==      ===        ==        ==        ====    ====       =="
grn_print "=  ====  ==  ===========  ========  ======  ==  ===  ====  ="
grn_print "=  ====  ==  ===========  ========  =====  ====  ==  ====  ="
grn_print "==  =======  ===========  ========  =====  ====  ==  ====  ="
grn_print "====  =====      =======  ========  =====  ====  ==       =="
grn_print "======  ===  ===========  ========  =====  ====  ==  ======="
grn_print "=  ====  ==  ===========  ========  =====  ====  ==  ======="
grn_print "=  ====  ==  ===========  ========  ======  ==  ===  ======="
grn_print "==      ===        =====  ========  =======    ====  ======="
grn_print "============================================================"

# ---- Install Homebrew ----
# --------------------------
blue_pprint "Installing Homebrew..."
if ! command -v brew >/dev/null; then
  grn_print "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
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

if ! brew ls --versions vim >/dev/null; then
  grn_print "Installing Vim..."
  brew install vim --with-override-system-vi
fi

if ! brew tap | grep uptech >/dev/null; then
  grn_print 'Brew tapping "uptech/homebrew-oss"...'
  brew tap "uptech/homebrew-oss"
fi

brew_install uptech/oss/git-ps

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

grn_print "Setting global ruby version to $ruby_version"
rbenv global "$ruby_version"

grn_print "Setting shell ruby version to $ruby_version"
rbenv shell "$ruby_version"

# ---- Install Gems ----
# ----------------------
gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    grn_print "Updating $@"
    gem update "$@"
  else
    grn_print "Installing $@"
    gem install "$@"
    rbenv rehash
  fi
}

blue_pprint "Installing Gems..."
grn_print "Updating RubyGems system software"
gem update --system

gem_install_or_update 'bundler'

# ---- Finder Setup ----
# ----------------------
blue_pprint "Setting up Finder..."
grn_print "Showing hidden files"
defaults write com.apple.finder AppleShowAllFiles -bool true
killall Finder

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

# ---- Finish Setup ----
# ----------------------
pprint ""
grn_print "Your system is now settop"
