source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring Sublime Merge..."

LICENSE_DIR="$HOME/Library/Application Support/Sublime Merge/Local"
LICENSE_FILE="$LICENSE_DIR/License.sublime_license"

if [ -f "$LICENSE_FILE" ]; then
  yel_print "Sublime Merge license already installed. Skipping..."
  return 0
fi

# Check if 1Password CLI has at least one account registered via the Desktop
# App integration. op account list --format json never shows an interactive
# prompt — it always exits 0 and returns either a populated array or [].
check_op_integration() {
  local accounts
  accounts=$(op account list --format json 2>/dev/null)
  [ "$accounts" != "[]" ] && [ -n "$accounts" ]
}

if ! check_op_integration; then
  red_print "1Password CLI is not connected to the Desktop App."
  red_print "Please complete the following steps:"
  red_print "  1. Open the 1Password app (just installed — it will prompt you to sign in)"
  red_print "  2. Complete account sign-in and setup"
  red_print "  3. Go to Settings (Cmd + ,) > Developer"
  red_print "  4. Check 'Integrate with 1Password CLI'"
  printf "\e[33mPress Enter to try again...\e[0m "
  read -r

  if ! check_op_integration; then
    red_print "Still not connected. Skipping Sublime Merge license config."
    red_print "Re-run settop.sh once 1Password is set up."
    return 0
  fi
fi

grn_print "Fetching Sublime Merge license from 1Password..."

op_output=$(op item get "Sublime Merge License" --vault "Personal" --fields 'label=license key' 2>&1)
if [ $? -ne 0 ]; then
  red_print "Failed to fetch Sublime Merge license from 1Password."
  red_print "Error: $op_output"
  red_print "Skipping. Re-run settop.sh to try again."
  return 0
fi

mkdir -p "$LICENSE_DIR"
printf '%s' "$op_output" > "$LICENSE_FILE"
grn_print "Sublime Merge license installed."
