# Settop a.k.a Set[up Lap]top

This is a script for setting up my laptop. It works in conjunction with my
[dotfiles repo](https://github.com/RyanHedges/dotfiles)

### Download the project
This is intended to be used on a brand new machine so you'll have to curl the
project and unzip it.

```bash
$ curl -o ~/settop-master.zip -Lk https://github.com/ryanhedges/settop/archive/master.zip
$ unzip -j ~/settop-master.zip -d ~/init-settop
$ rm ~/settop-master.zip
```

### Github setup

1. Set up [ssh key for
github](https://help.github.com/articles/which-remote-url-should-i-use/#cloning-with-ssh-urls). The script is based on the directions found [on github's documentation](https://github.com/github/docs/blob/484596a3e1a0adf364f0560c6fce34d8823ea36f/content/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent.md).

   ```bash
   $ source ~/init-settop/settop_ssh.sh
   ```

   This will:
    * Generates a ssh key
    * Creates the `.ssh/config` file
    * Adds key to a ssh-agent using `--apple-use-keychain` for passphrase
    * Copy contents of `id_ed25519.pub` to your clipboard for pasting into GitHubs
      account settings.

   If there is anything in the ssh directory, it will NOT generate a key. You may want to copy from your keys over from an existing computer if possible.

    After setting up the new SSH key with github you can [test it
with](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection):
    ```
    $ ssh -T git@github.com
    ```
    Continue by adding 'github.com' to the list of known hosts and you should
see..
    > Hi RyanHedges! You've successfully authenticated, but GitHub does not
    > provide shell access

2. [Add the key to
Github](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)

### Setup laptop

1. Run the settop script

  ```bash
  $ sh ~/init-settop/settop.sh
  ```

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
