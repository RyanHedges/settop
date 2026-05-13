#!/bin/bash

# You can run this script individually with:
#   bash configs/night-shift/setup.sh

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring Night Shift..."

RESULT=$(swift "$SETTOP_ROOT/configs/night-shift/nightshift.swift")

STATE="${RESULT%%|*}"
DESC="${RESULT#*|}"

if [[ "$STATE" == "CONFIGURED" ]]; then
  grn_print "Configured Night Shift ($DESC)."
elif [[ "$STATE" == "ALREADY_CONFIGURED" ]]; then
  yel_print "Night Shift already configured ($DESC)."
elif [[ "$STATE" == "WARNING" ]]; then
  red_print "Night Shift warning — $DESC"
else
  yel_print "Failed to configure Night Shift: $RESULT"
fi
