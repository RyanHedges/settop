#!/bin/sh
pprint() {
  local msg="$1"; shift
  printf "\n$msg\n"
}
set -e

pprint "Installing Homebrew..."
if ! command -v brew >/dev/null; then
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
  pprint "Homebrew already installed"
fi

pprint "Updating Homebrew..."
brew update

pprint "Installing Hombrew packages"
echo "Installing git..."
brew install git

pprint "Checking for ~/.dotfiles"
if [ ! -d ~/.dotfiles ]; then
  echo "Cloning RyanHedges/dotfiles into ~/.dotfiles"
  git clone git@github.com:RyanHedges/dotfiles.git ~/.dotfiles
else
  echo "Using existing ~/.dotfiles"
fi

pprint "Creating links to ~/.dotfiles..."
echo "linking to gitconfig"
ln -s ~/.dotfiles/gitconfig ~/.gitconfig

#brew install neovim
#brew install rbenv
#brew install ruby-build
#brew install postgres
#
#ruby_version="$(rbenv install -l | grep -v - | tail -l | sed -e 's/^ *//')"
