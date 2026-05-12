#!/bin/bash

# Shared in-memory state for the current run of settop.sh.
# Variables defined here do not persist across executions.

# Array to hold reasons why a logout/restart is required.
REQUIRES_RESTART_REASONS=()

# Helper function to register a restart requirement.
# Usage: require_restart "Keyboard: Increased KeyRepeat rate"
require_restart() {
  local reason="$1"
  REQUIRES_RESTART_REASONS+=("$reason")
}
