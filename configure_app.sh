# configure_app.sh — sourced by settop.sh
#
# Provides the configure_app() function, which sources configs/<name>/setup.sh.
# This lets you scaffold app installs first and add config later without breaking
# the flow.

configure_app() {
  local name="$1"
  local config_file="$SCRIPT_DIR/configs/$name/setup.sh"

  if [ -f "$config_file" ]; then
    source "$config_file"
  else
    yel_print "No config found for '$name' at configs/$name/setup.sh. Skipping..."
  fi
}
