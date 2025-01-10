#!/bin/bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"

gcheckout() { # Fetch and list all branches available and checkout on selection via fzf
  echo "Fetching... "
  git fetch

  selected_branch=$( git branch --all | sed 's/^[* ]*//' | sed 's#^remotes/origin/##' | fzf --height=20% --info=inline --reverse)
  # Check if a branch was selected
  if [ -n "$selected_branch" ]; then
    # Concatenate the selected branch into a string
    result="You selected branch: $selected_branch"
    echo "$result"
    git checkout $selected_branch
  else
    echo "No branch selected."
  fi
}
gc () { # shurtcut
  gcheckout()
}

gclean() { # Clean all the branch that have not more remote
  # https://stackoverflow.com/a/33548037
  git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
}
