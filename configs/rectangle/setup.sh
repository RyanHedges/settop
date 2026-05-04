blue_pprint "Configuring Rectangle..."

# Rectangle reads RectangleConfig.json on launch and renames it with a timestamp,
# so we re-copy on every run to pick up any updates committed to this repo.
# https://github.com/rxhanson/Rectangle/tree/v0.95#import--export-json-config
if [ -f "$SCRIPT_DIR/configs/rectangle/RectangleConfig.json" ]; then
  mkdir -p "$HOME/Library/Application Support/Rectangle"
  cp -f "$SCRIPT_DIR/configs/rectangle/RectangleConfig.json" \
    "$HOME/Library/Application Support/Rectangle/RectangleConfig.json"
  grn_print "Rectangle config applied"
else
  yel_print "RectangleConfig.json not found in configs/rectangle/"
fi
