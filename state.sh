#!/bin/bash

# Shared in-memory state for the current run of settop.sh.
# Variables defined here do not persist across executions.

# Array to hold reasons why a logout/restart is required.
# Only initialize the array if it hasn't been defined yet in the current shell session.
if ! declare -p REQUIRES_RESTART_REASONS >/dev/null 2>&1; then
  REQUIRES_RESTART_REASONS=()
fi

# Helper function to register a restart requirement.
# Usage: require_restart "Keyboard: Increased KeyRepeat rate"
require_restart() {
  local reason="$1"
  REQUIRES_RESTART_REASONS+=("$reason")
}
