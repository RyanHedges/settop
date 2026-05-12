#!/bin/bash

# Securely resolve the absolute path to the root of the project if not already set
if [ -z "$SETTOP_ROOT" ]; then
  SOURCE="${BASH_SOURCE[0]:-$0}"
  while [ -L "$SOURCE" ]; do DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"; SOURCE="$(readlink "$SOURCE")"; [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"; done
  SETTOP_ROOT="$(cd -P "$(dirname "$SOURCE")" && pwd)"
fi

# Helper function to easily source files relative to the project root
import() {
  local target="$1"
  local target_path="$SETTOP_ROOT/$target"
  
  if [ -f "$target_path" ]; then
    source "$target_path"
  else
    echo -e "\e[31mError: Cannot import '$target'. File not found at $target_path\e[0m"
    exit 1
  fi
}
