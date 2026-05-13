source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring TextEdit..."

CURRENT_RICH_TEXT=$(defaults read com.apple.TextEdit RichText 2>/dev/null || echo "")
if [ "$CURRENT_RICH_TEXT" != "0" ]; then
  grn_print "Set RichText to false..."
  defaults write com.apple.TextEdit RichText -bool false || red_print "Failed to set RichText"
  killall TextEdit 2>/dev/null || true
else
  yel_print "RichText already false. Skipping..."
fi
