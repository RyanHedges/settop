#!/bin/bash

# You can run this script individually with:
#   bash configs/night-shift/setup.sh
# 
# $SCRIPT_DIR is passed from settop.sh. If running locally, we determine it here.
if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  source "$SCRIPT_DIR/colors.sh"
fi

blue_pprint "Configuring Night Shift..."

RESULT=$(swift "$SCRIPT_DIR/configs/night-shift/nightshift.swift")

STATE="${RESULT%%|*}"
DESC="${RESULT#*|}"

if [[ "$STATE" == "CONFIGURED" ]]; then
  grn_print "Configured Night Shift ($DESC)."
elif [[ "$STATE" == "ALREADY_CONFIGURED" ]]; then
  yel_print "Night Shift already configured ($DESC)."
else
  yel_print "Failed to configure Night Shift: $RESULT"
fi
