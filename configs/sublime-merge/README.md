# Sublime Merge

This configuration automates the installation of the Sublime Merge license using the 1Password CLI (`op`).

### Mechanism

Sublime Merge stores its license at `~/Library/Application Support/Sublime Merge/Local/License.sublime_license`. This script fetches the license string from a 1Password item named "Sublime Merge License" in the "Personal" vault (Software License template, field: "license key") and writes it to that file.

### 1Password CLI integration requirement

`op` relies on the 1Password Desktop App integration to authenticate. Before the license can be fetched, the app must be open, signed in, and the CLI integration must be enabled:

1. Open the 1Password app (first run will prompt for account sign-in)
2. Complete account sign-in and setup
3. Go to **Settings** (Cmd + ,) > **Developer**
4. Check **Integrate with 1Password CLI**

The script detects whether the integration is ready by running `op account list --format json`, which never shows an interactive prompt — it always exits 0 and returns either a populated JSON array or `[]`. If the integration is not ready, the script prints the above instructions and waits for you to enable it before retrying once. If the retry also fails, it skips gracefully and prints a message to re-run `settop.sh` once 1Password is set up.

### Idempotency

If the license file already exists, the script skips immediately. Re-running `settop.sh` is safe.
