#Settop a.k.a Set[up Lap]top

testing prs

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
github](https://help.github.com/articles/which-remote-url-should-i-use/#cloning-with-ssh-urls)

  ```bash
  $ source ~/settop/settop_ssh.sh
  ```

  This will:
    * Generates a ssh key
    * Adds key to a ssh-agent.
    * Copy contents of `id_rsa.pub` to your clipboard for pasting into GitHubs
      account settings.

  If there is something in the ssh directory, it will NOT generate a key.

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
