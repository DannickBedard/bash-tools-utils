#!/bin/bash

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
cp ~/.bashrc ~/.bashrc.bak
cp ./.bashrc ~/.bashrc

# copie bash_utils to home
cp  ./bash_utils ~/bash_utils

# cp .bash_projects.json to home if not exist
if [ ! -f ~/.bash_projects.json ]; then
  # to not overwrite the existing user config
  cp ./.bash_projects.json ~/.bash_projects.json
fi

# reload bashrc
source ~/.bashrc
