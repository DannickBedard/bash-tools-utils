#!/usr/bin/env bash

# git pull if possible.

# loop through arguments
for arg in "$@"; do
  if [[ "$arg" == "--pull" ]]; then
    echo "Pulling bash-tools-utils..."
    git pull
    echo "Pulling oil-bash-tools-utils..."
    git -C ~/oil:/C/Users/danni/bash-tools-utils pull
    break
  fi

done


# copie .bashrc to home
# # make a backup of the original file
if [[ -f ~/bash_utils.sh ]]; then
  cp ~/bash_utils.sh ~/.bash_utils.sh.bak
fi
cp ./bash_utils.sh ~/bash_utils.sh

# copie bash_utils to home
cp -r ./bash_utils ~/

# cp .bash_projects.json to home if not exist
if [[ ! -f ~/.bash_projects.json ]]; then
  # to not overwrite the existing user config
  cp ./bash_projects.json ~/bash_projects.json
fi

# reload config file
# add source bash_utils.sh to the config file. if already present in file do nothing

config_file="$HOME/.bashrc"

if [[ -f ~/.zshrc ]]; then
  config_file="$HOME/.zshrc"
fi

if [[ ! -f "$config_file" ]]; then
  touch config_file
fi

if [[ $(grep -c 'source ~/bash_utils.sh' "$config_file") -eq 0 ]]; then
  echo "source ~/bash_utils.sh" >> "$config_file"
fi

source config_file
