# AGENTS.md

Personal macOS bootstrap (bash). No tests, no lint, no CI. Real verification is running it on a fresh macOS install.

## Layout

- `settop.sh` — main entrypoint. Run with **bash**, not sh (uses arrays, `[[ ]]`, `${VAR/#\~/$HOME}`). Shebang is `#!/bin/bash` and was fixed deliberately (`56d7f5e`).
- `colors.sh` — defines `pprint`, `grn_print`, `yel_print`, `blue_print`, `blue_pprint`. **Always use these instead of raw `echo`/`printf`.**
- `configure_app.sh` — defines `configure_app <name>`, which **sources** `configs/<name>/setup.sh` (does not exec). Missing dir prints a warning and continues.
- `configs/<name>/setup.sh` — sourced from `settop.sh`, so it inherits `SCRIPT_DIR`, the color helpers, and `brew_install*`. See `configs/README.md` for the contract.
- `clone_and_link.sh` — creates `~/run_settop.sh` symlink, then refuses to do anything if it already exists.
- `scripts/bitbucket/add-account.sh` — separate flow, run **after** `settop.sh`. Adds a per-client Bitbucket SSH key + git includeIf.
- `settop_ssh.sh` — **DEPRECATED**, kept for reference only. Do not extend.
- `manual_setup.md` — manual checklist for things scripts can't automate yet.

## Conventions an agent will get wrong without help

- **Idempotency is mandatory.** Every action must check state first; print green when doing work, yellow when skipping. Re-running the script must be safe.
- `set -e` is on in `settop.sh`. Because `configs/*/setup.sh` are **sourced**, an `exit 1` inside a config aborts the entire run on purpose (e.g. GitHub auth failure is unrecoverable — see `configs/github/setup.sh`). Use `return 1` only if you intend the parent to keep going.
- Use the existing helpers in `settop.sh`: `brew_install`, `brew_install_cask`, `gem_install_or_update`. They already do the "is it installed?" check.
- When adding a new app config, follow `configs/README.md`: `setup.sh` is the entry point, use `defaults write` directly (no wrappers), `cp -f` for one-shot imports (Rectangle), `ln -sf` for files read on every launch.
- macOS-only assumptions throughout: `defaults write`, `mas`, `scutil`, `killall Finder/SystemUIServer/ControlCenter`, `ssh-add --apple-use-keychain`, `chsh`. Don't try to make these portable.
- Several scripts assume `$HOME` ends in `/ryanhedges` (e.g. `clone_and_link.sh` hardcodes `~/projects/ryanhedges/settop/`). Don't generalize without a reason.

## Multi-account SSH + git routing (the subtle area)

This area has had several bug-fix commits — read carefully before changing.

- `~/.ssh/config.d/*.conf` matches by hostname only. With two GitHub or two Bitbucket accounts, SSH cannot pick the right key from config alone — whichever `Host bitbucket.org` block is loaded first wins.
- Per-account routing is done in **git**, not ssh: `~/.dotfiles/git/gitconfig-<alias>` sets `core.sshCommand = "ssh -i <key> -o IdentitiesOnly=yes -F /dev/null"`, and the main `~/.dotfiles/git/gitconfig` includes it via `includeIf.gitdir:<absolute-path-with-trailing-slash>/.path`.
- When writing the includeIf with `git config --add`, pass the key as `includeIf.gitdir:<path>/.path` — **do not** wrap the gitdir condition in quotes yourself; git escapes them and you get `[includeIf "\"gitdir:...\""]` which never matches (see commits `ad40a0a`, `d8ed364`, `4e95702`).
- gitdir paths must be **absolute** (no `~`) and **end with `/`**. Trailing slash is required for matching.
- `Include ~/.ssh/config.d/*.conf` must sit at the **top** of `~/.ssh/config`. OpenSSH stops at the first `Host` match, so an Include at the bottom is shadowed.
- For testing a specific key, bypass ssh config: `ssh -i ~/.ssh/<key> -o IdentitiesOnly=yes -F /dev/null -T git@<host>`. A bare `ssh -T git@bitbucket.org` is unreliable with multiple accounts.
- Bitbucket returns exit 1 on successful auth; check stdout for `authenticated via ssh key` / `logged in as`.

## Dependencies an agent might miss

- `settop.sh` clones `RyanHedges/dotfiles` into `~/.dotfiles` and runs `~/.dotfiles/bin/install`. Anything that touches `~/.dotfiles/git/gitconfig*` assumes that repo's structure.
- `configs/github/setup.sh` requires `~/.ssh/id_ed25519` (created earlier by `configs/ssh/setup.sh`) — order in `settop.sh` matters: ssh before github.
- `gh` must be authenticated with `admin:public_key` and `admin:ssh_signing_key` scopes; the script refreshes scopes if missing.
- `mas install` requires the App Store app to be signed in interactively first (see README "Setup App Store").
- `xcode-select --install` opens a GUI dialog; cannot be fully automated.

## Running / verifying

- Full run: `bash ~/init-settop/settop.sh` (first run) or `~/run_settop.sh` (after `clone_and_link.sh`).
- Bitbucket add: `bash scripts/bitbucket/add-account.sh`.
- Quick syntax check before committing: `bash -n settop.sh configure_app.sh colors.sh clone_and_link.sh settop_ssh.sh configs/*/setup.sh scripts/bitbucket/add-account.sh`.
- Both `settop.sh` and `add-account.sh` are interactive (passphrase, nickname, email, dirs, gh browser auth) — they cannot run unattended.

## Commit style

Short imperative subject in sentence case, ~50 chars: `Fix ...`, `Add ...`, `Migrate ...`, `Document ...`. Body when context needs preserving which only references things that have already been committed and "hypothetical" future changes if commits are being split into multiple. Focus on communicating _WHY_ a change was needed, the problem that it's solving. We want future readers to understand the purpose and reasoning that went into a change. Small commits are preferred that work in isolation and have only dependencies on the previous commits.
