# Settop a.k.a Set[up Lap]top

This is a script for setting up my laptop. It works in conjunction with my
[dotfiles repo](https://github.com/RyanHedges/dotfiles)

### Download the project
This is intended to be used on a brand new machine so you'll have to curl the
project and unzip it.

```bash
$ curl -o ~/settop-master.zip -Lk https://github.com/ryanhedges/settop/archive/master.zip
$ unzip -j ~/settop-master.zip -d ~/settop
$ rm ~/settop-master.zip
```

### Github setup

1. Set up [ssh key for
github](https://help.github.com/articles/which-remote-url-should-i-use/#cloning-with-ssh-urls). The script is based on the directions found [on github's documentation](https://github.com/github/docs/blob/484596a3e1a0adf364f0560c6fce34d8823ea36f/content/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent.md).

   ```bash
   $ source ~/settop/settop_ssh.sh
   ```

   This will:
    * Generates a ssh key
    * Creates the `.ssh/config` file
    * Adds key to a ssh-agent using `--apple-use-keychain` for passphrase
    * Copy contents of `id_ed25519.pub` to your clipboard for pasting into GitHubs
      account settings.

   If there is anything in the ssh directory, it will NOT generate a key. You may want to copy from your keys over from an existing computer if possible.

2. [Add the key to
Github](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)

### Setup laptop

1. Run the settop script

  ```bash
  $ sh ~/settop/settop.sh
  ```

## Helpful resources used while making this
- [thoughtbot laptop](https://github.com/thoughtbot/laptop)
- [Brian Miller Dotfiles](https://github.com/BRIMIL01/dotfiles)
