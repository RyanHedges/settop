source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring Rectangle..."

# Rectangle reads RectangleConfig.json on launch and renames it with a timestamp,
# so we re-copy on every run to pick up any updates committed to this repo.
# https://github.com/rxhanson/Rectangle/tree/v0.95#import--export-json-config
if [ -f "$SETTOP_ROOT/configs/rectangle/RectangleConfig.json" ]; then
  mkdir -p "$HOME/Library/Application Support/Rectangle"
  cp -f "$SETTOP_ROOT/configs/rectangle/RectangleConfig.json" \
    "$HOME/Library/Application Support/Rectangle/RectangleConfig.json"
  grn_print "Rectangle config applied"
  yel_print "════════════════════════════════════════════════════════"
  yel_print "  ⚠ ACTION REQUIRED: launch Rectangle once for it to"
  yel_print "    register the login helper. After first launch, it"
  yel_print "    will automatically start on login."
  yel_print "════════════════════════════════════════════════════════"
else
  yel_print "RectangleConfig.json not found in configs/rectangle/"
fi
