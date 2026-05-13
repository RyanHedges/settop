source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/import.sh"
import "colors.sh"

blue_pprint "Configuring Sublime Merge..."

LICENSE_DIR="$HOME/Library/Application Support/Sublime Merge/Local"
LICENSE_FILE="$LICENSE_DIR/License.sublime_license"

if [ -f "$LICENSE_FILE" ]; then
  yel_print "Sublime Merge license already installed. Skipping..."
  return 0
fi

grn_print "Sublime Merge license configuration placeholder..."
