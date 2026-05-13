#!/bin/bash

# You can run this script individually with:
#   bash configs/macos-display/setup.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring built-in display resolution..."

# Capture stdout only — the Swift script writes its STATE|DESC result to stdout
# and emits discovery / selection info to stderr so the user sees it stream
# through as the script runs.
RESULT=$(swift "$SETTOP_ROOT/configs/macos-display/display-resolution.swift")

STATE="${RESULT%%|*}"
DESC="${RESULT#*|}"

if [[ "$STATE" == "CONFIGURED" ]]; then
  grn_print "Configured display resolution ($DESC)."
elif [[ "$STATE" == "ALREADY_CONFIGURED" ]]; then
  yel_print "Display resolution already configured ($DESC)."
elif [[ "$STATE" == "ERROR" ]]; then
  red_print "Display resolution error: $DESC"
else
  red_print "Unexpected response from display-resolution.swift: $RESULT"
fi
