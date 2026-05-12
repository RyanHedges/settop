#!/bin/sh
set -e

# Robustly resolve the symlink to find the true project root
SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"; SOURCE="$(readlink "$SOURCE")"; [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"; done
SETTOP_ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"

source "$SETTOP_ROOT/import.sh"
import "colors.sh"

REPO_URL="git@github.com:RyanHedges/settop.git"
TARGET="$HOME/projects/ryanhedges/settop/settop.sh"
REPO_DIR="$( dirname "$TARGET" )"
LINK="$HOME/run_settop.sh"

blue_pprint "Cloning settop repo and sym linking it for use and development..."

# 1) If anything exists at $LINK (file, dir, or symlink), skip.
if [ -e "$LINK" ]; then
  yel_print "Skipping: '$LINK' already exists."
  exit 0
else
  blue_print "'$LINK' doesn't exist yet..."
fi

# 2) If the file doesn't exist, clone it
if [ ! -e "$TARGET" ]; then
  grn_print "'$TARGET' not found. Cloning repo into '$REPO_DIR'..."
  mkdir -p "$REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR"
else
  blue_print "'$TARGET' already exists..."
fi

# 3) Otherwise, create the symlink.
grn_print "Creating symlink: $LINK → $TARGET"
ln -s "$TARGET" "$LINK"
grn_print "✔ Symlink created."

