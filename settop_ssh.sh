#!/bin/sh

echo "Checking if ssh keys exist in ~/.ssh"

if [ "$(ls -A ~/.ssh)" ]; then
  echo "This computer has the following files in ~/.ssh:"
  echo "$(ls -A ~/.ssh)"
else
  echo "Generating ssh key..."
  echo "Enter the github account email for your key:"
  read email
  ssh-keygen -t ed25519 -C "$email"

  echo "Ensuring that the ssh-agent is enabled..."
  eval "$(ssh-agent -s)"

cat > ~/.ssh/config << EOF
Host *
 AddKeysToAgent yes
 UseKeychain yes
 IdentityFile ~/.ssh/id_ed25519
EOF

  echo "Adding key to agent..."
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519

  echo "Copying contents of id_ed25519.pub to clipboard..."
  pbcopy < ~/.ssh/id_ed25519.pub
  echo "Successfully copied"
fi

