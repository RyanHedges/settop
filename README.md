# Settop a.k.a Set[up Lap]top

This is a script for setting up my laptop. It works in conjunction with my
[dotfiles repo](https://github.com/RyanHedges/dotfiles)

### Set up Laptop
* Make sure that the home directory is `ryanhedges` so that scripts and things that are currently not dynamic properly look for the files.

### Download the project
This is intended to be used on a brand new machine so you'll have to curl the
project and unzip it.

```bash
$ curl -o ~/settop-master.zip -Lk https://github.com/ryanhedges/settop/archive/master.zip
$ unzip ~/settop-master.zip -d ~/
$ mv ~/settop-master ~/init-settop
$ rm ~/settop-master.zip
```

### Setup App Store

Open app store and ensure that the apple account that downloads Mac apps is
signed in. This can be triggered by going to Account Settings. I have to switch
my personal Apple ID to my application Apple ID for this to work.

If you encounter an error like:
```
Error: No downloads initiated for ADAM ID 497799835
```
it indicates the App Store account is not properly authenticated or the app
is not available for download with the current Apple ID. Verify you are signed
in with the correct application Apple ID.

### Setup laptop

1. Run the settop script

    ```bash
    $ sh ~/init-settop/settop.sh
    ```

   First run will prompt for:
   - SSH key passphrase (save to your password manager)
   - A nickname for the machine's SSH keys (defaults to macOS computer name, used for GitHub UI identification)
   - `gh` CLI authentication via browser (opens browser to authenticate, requests `admin:public_key` and `admin:ssh_signing_key` scopes)
   - Additional browser prompts if `gh` token needs scope refresh (only on re-runs with existing auth)

   SSH keys are uploaded to GitHub as both authentication and signing keys.
   Verified commits are configured automatically using SSH signing (configured in `~/.dotfiles/git/gitconfig`).

2. Run the script to copy this repo for future development

    ```bash
    $ sh ~/init-settop/clone_and_link.sh
    ```

3. Remove the initial download

    ```bash
    $ rm -rf ~/init-settop
    ```

### Manual Setup

Read the [manual setup guide](manual_setup.md) to run through the checklist

## Helpful resources used while making this
- [thoughtbot laptop](https://github.com/thoughtbot/laptop)
- [Brian Miller Dotfiles](https://github.com/BRIMIL01/dotfiles)
