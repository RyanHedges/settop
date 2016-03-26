#Settop a.k.a Set[up Lap]top

### Github setup
1. Set up [ssh key for github](https://help.github.com/articles/which-remote-url-should-i-use/#cloning-with-ssh-urls)

  ```bash
  $ source settop_ssh.sh
  ```

  This generates a ssh key and adds it to a ssh-agent. It will also copy the
  contents of `id_rsa.pub` to your clipboard for pasting into GitHubs account
  settings. If there is something in the ssh directory, it will not generate a
  key.

2. [Add the key to Github](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)
