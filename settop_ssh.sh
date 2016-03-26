#!/bin/sh

echo "Checking if ssh keys exist in ~/.ssh"

if [ "$(ls -A ~/.ssh)" ]; then
  echo "This computer has the following files in ~/.ssh:"
  echo "$(ls -A ~/.ssh)"
else
  echo "Generating ssh key..."
  echo "Enter the github account email for your key:"
  read email
  ssh-keygen -t rsa -b 4096 -C "$email"

  echo "Ensuring that the ssh-agent is enabled..."
  eval "$(ssh-agent -s)"

  echo "Adding key to agent..."
  ssh-add ~/.ssh/id_rsa

  echo "Copying contents of id_rsa.pub to clipboard..."
  pbcopy < ~/.ssh/id_rsa.pub
  echo "Successfully copied"
fi

