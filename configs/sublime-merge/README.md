# Sublime Merge

This configuration automates the installation of the Sublime Merge license using the 1Password CLI (`op`).

### Mechanism

Sublime Merge stores its license at `~/Library/Application Support/Sublime Merge/Local/License.sublime_license`. This script securely fetches the license string from a 1Password item (Software License template) and injects it into that file.

Because `op` relies on the 1Password Desktop App for unlocking, the CLI integration must be enabled manually in the Desktop App (`Settings > Developer > Connect with 1Password CLI`). If it is not enabled or if the user cancels the Touch ID prompt, the script will catch the error and present an interactive retry loop.
