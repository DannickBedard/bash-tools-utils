#!/bin/bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"

# Open a pr of the current branch in gitbucket on the destination branche chosen in fzf. 
pr() {
   # Get the list of all Git branches and pass them to fzf for selection
  selected_branch=$( git branch --all | sed 's/^[* ]*//' | sed 's#^remotes/origin/##' | fzf)

  # Check if a branch was selected
  if [ -n "$selected_branch" ]; then
    # Concatenate the selected branch into a string
    result="You selected branch: $selected_branch"
    echo "$result"

    # Base Bitbucket URL
    BITBUCKET_URL="https://bitbucket.org"

    # Get the repository owner and name from Git remote
    REMOTE_URL=$(git remote get-url origin)
    REPO_INFO=$(echo "$REMOTE_URL" | sed -E 's#.*/([^/]+)/([^/]+)(\.git)?$#\1 \2#')
    REPO_OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
    REPO_NAME=$(echo "$REPO_INFO" | awk '{print $2}' | sed 's/\.git$//') # Remove .git if present

    # Current branch name
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Destination branch (customize as needed)
    DESTINATION_BRANCH="release/v2024.3"

    # Construct the Pull Request URL
    PR_URL="$BITBUCKET_URL/$REPO_OWNER/$REPO_NAME/pull-requests/new?source=$CURRENT_BRANCH&dest=$selected_branch"

    # Open the URL in the default browser
    echo "Opening: $PR_URL"
    if command -v start &>/dev/null; then
        start "$PR_URL"
    else
        echo "Could not detect a browser open command. Please open this URL manually: $PR_URL"
    fi
  else
    echo "No branch selected."
  fi

}
