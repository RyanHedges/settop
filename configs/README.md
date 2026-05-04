# App Configs

Each subdirectory contains the configuration for a single app, orchestrated by `configure_app <name>` in `settop.sh`.

## Structure

```
configs/
├── <app-name>/
│   ├── setup.sh              # Required — the entry point, sourced by configure_app
│   └── ...                   # Optional — JSON configs, READMEs, etc.
```

## Rules

- **`setup.sh` is always the entry point** — sourced directly by `configure_app`. If missing, a yellow warning is printed and execution continues.
- **Use `defaults write` directly** — no wrapper functions. Read the script to see exactly what runs.
- **Copy JSON configs with `cp -f`** — some apps (like Rectangle) do a one-shot import of a JSON file on launch. Re-copy on every run so updates to this repo are picked up.
- **Symlink persistent configs with `ln -sf`** — for apps that read config files on every launch (not one-shot imports), symlink to `~/.dotfiles/` or keep the file here.
- **Add `.md` files freely** — use them for context that code or comments can't easily convey (rationale, known issues, manual steps).
- **Keep scripts idempotent** — running `configure_app` multiple times should produce the same result.
