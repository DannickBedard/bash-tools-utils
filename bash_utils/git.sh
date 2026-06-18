#!/usr/bin/env bash

create_branch_from_ticket() {

  local prefix="BSP"   # default prefix
  local ticket_input=""
  local description=""

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prefix)
        prefix="$2"
        shift 2
        ;;
      -n|--name)
        prefix=""
        ticket_input="$2"
        break
        ;;
      *)
        ticket_input="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$ticket_input" ]]; then
    echo "❌ Usage: create_branch_from_ticket [-p <prefix>] <ticket-number | jira-url>"
    return 1
  fi

  # Extract ticket number if Jira URL is provided
  local ticket_number
  if [[ "$ticket_input" =~ https?://[^/]+/browse/([A-Za-z]+-[0-9]+) ]]; then
    ticket_number="${BASH_REMATCH[1]}"
  else
    ticket_number="$ticket_input"
  fi

  # Ensure prefix if not already there
  if [[ "$prefix" != "" ]]; then
    if [[ ! "$ticket_number" =~ ^${prefix}- ]]; then
      ticket_number="${prefix}-${ticket_number}"
    fi
  fi

  echo "branch name: $ticket_number"

  local existing_branch
  existing_branch=$(git branch -a --sort=-committerdate | sed 's/^[* ]*//' | grep -F "$ticket_number" | sort -u)

  if [[ -n "$existing_branch" ]]; then
    echo "⚠️  Found existing branch(es) containing '$ticket_number':"
    echo "$existing_branch"

    local choice
    choice=$(printf "Use existing\nCreate new" | default_fzf --prompt="Branch already exists. What do you want to do? > " )

    if [[ "$choice" == "Use existing" ]]; then
      local selected_existing
      selected_existing=$(echo "$existing_branch" | default_fzf --prompt="Select existing branch > ")
      if [[ -z "$selected_existing" ]]; then
        echo "❌ No branch selected."
        return 1
      fi
      selected_existing="${selected_existing#remotes/origin/}"
      git stash
      echo "🔀 Checking out existing branch: $selected_existing"
      git checkout "$selected_existing"
      echo "✅ Switched to existing branch."
      apply_stash
      return 0
    else
      read -rp "📝 Enter suffixes (optionnal e.g. v1) : " description
    fi
  fi

  echo "🔄 Fetching branches..."
  spinner git fetch -p -q 

  # Check if any branch already contains the ticket number
  # check if branch existe after fetching
  existing_branch=$(git branch -a --sort=-committerdate | sed 's/^[* ]*//' | grep -F "$ticket_number" | sort -u)

  if [[ -n "$existing_branch" ]]; then
    echo "⚠️  Found existing branch(es) containing '$ticket_number':"
    echo "$existing_branch"

    local choice
    choice=$(printf "Use existing\nCreate new" | default_fzf --prompt="Branch already exists. What do you want to do? > " )

    if [[ "$choice" == "Use existing" ]]; then
      local selected_existing
      selected_existing=$(echo "$existing_branch" | default_fzf --prompt="Select existing branch > ")
      if [[ -z "$selected_existing" ]]; then
        echo "❌ No branch selected."
        return 1
      fi
      selected_existing="${selected_existing#remotes/origin/}"
      git stash
      echo "🔀 Checking out existing branch: $selected_existing"
      git checkout "$selected_existing"
      echo "✅ Switched to existing branch."
      apply_stash
      return 0
    else
      read -rp "📝 Enter suffixes (optionnal e.g. v1) : " description
    fi
  fi

  echo "Selecting base branch..."
  base_branch=$(git_select_base_branch | tee /dev/tty) || exit 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi
  echo "✅ Selected base branch: $base_branch"
  base_branch="${base_branch#remotes/origin/}"

  local branch_type
  branch_type=$(printf "bugfix\nfeature" | default_fzf --prompt="Select branch type > ")
  if [[ -z "$branch_type" ]]; then
    echo "❌ No branch type selected."
    return 1
  fi


  local new_branch="${branch_type}/${ticket_number}"
  if [[ -z "$description" ]]; then
    read -rp "📝 Enter suffixes (optionnal e.g. v1) : " description
  fi

  if [[ -n "$description" ]]; then
    description=$(echo "$description" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    new_branch="${new_branch}-${description}"
  fi

  echo "🚀 Creating branch '$new_branch' from '$base_branch'..."
  git stash
  git checkout "$base_branch" && git pull origin "$base_branch"
  git checkout -b "$new_branch"
  apply_stash
  echo "✅ Branch created and switched: $new_branch"
}

git_select_base_branch() {
  local base_branch branch_list release_hotfix_list

  # Get all branches once
  branch_list=$(git branch --all \
    | sed 's/^[* ]*//' \
    | sed 's#^remotes/origin/##' \
    | sort -u)

  # Extract only release/hotfix branches
  release_hotfix_list=$(printf "%s\n" "$branch_list" | grep -E '^(release|hotfix)/' || true)

  # Pick from filtered or full list
  if [[ -n "$release_hotfix_list" ]]; then
    base_branch=$(printf "%s\n" "$release_hotfix_list" \
      | default_fzf --prompt="Select base branch (release/hotfix): ")
    if [[ -n "$base_branch" ]]; then
      echo "$base_branch"
      return 0 
    fi
  fi

  echo "📦 No release/hotfix branches found, showing all branches." >&2
  base_branch=$(printf "%s\n" "$branch_list" \
    | default_fzf --prompt="Select base branch (all): " --reverse)

  if [[ -n "$base_branch" ]]; then
    # Branch is selected
    echo "$base_branch"
    return 0 
  fi

  echo "📦 No branch chosen, showing all branches." >&2
  base_branch=$(printf "%s\n" "$branch_list" \
    | default_fzf --prompt="Select base branch (all): " --reverse)

  # No selection case
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected." >&2
    return 1
  fi

  # Return value by echoing it
  echo "$base_branch"
}

# Generic branch picker for cases that don't need the release/hotfix filtering
# that git_select_base_branch applies (e.g. picking a PR/upstream target like
# main/master/develop).
git_select_upstream_branch() {
  local branch_list upstream_branch

  branch_list=$(git branch --all \
    | sed 's/^[* ]*//' \
    | sed 's#^remotes/origin/##' \
    | sort -u)

  upstream_branch=$(printf "%s\n" "$branch_list" \
    | default_fzf --prompt="Select upstream branch (PR target): " --reverse)

  if [[ -z "$upstream_branch" ]]; then
    echo "❌ No upstream branch selected." >&2
    return 1
  fi

  echo "$upstream_branch"
}

git_stash_show() {
  apply_stash
}

apply_stash() {

  skip_stash() {
    echo "Skipping stash recup..."
    return 1
  }

  restore_stash() {
    echo "📦 Restoring stash..."
    git stash pop
    return 1
  }

  # ask to show stash or not
  local show_stash
  show_stash=$(printf "yes\nno\napply\nskip" | default_fzf --prompt="Show stash?  > ")

  if [ "$show_stash" == "skip" ]; then
    skip_stash
  fi

  if [ "$show_stash" == "yes" ]; then
    echo "📦 Showing stash..."
    git stash show

      # ask to see more detail or apply stash
      local show_detail
      show_detail=$(printf "yes\nno\napply\nskip" | default_fzf --prompt="Show detail?  > ")

      if [ "$show_detail" == "skip" ]; then
        skip_stash
      fi
      
      if [[ -n "$show_detail" ]]; then
        if [ "$show_detail" == "yes" ]; then
          echo "📦 Showing detail..."
          git stash show --patch
        fi
      fi

      if [ "$show_detail" == "apply" ]; then
        restore_stash
        return 0
      fi

      # ask to apply stash.
      local apply_stash
      apply_stash=$(printf "yes\nno\nskip" | default_fzf --prompt="Apply stash?  > ")

      if [ "$apply_stash" == "skip" ]; then
        skip_stash
      fi

      if [[ -n "$apply_stash" ]]; then
        if [ "$apply_stash" == "yes" ]; then
          restore_stash
          return 0
        fi
      fi

  fi

  if [ "$show_stash" == "apply" ]; then
    echo "📦 Applying stash..."
    git stash pop
    return 0
  fi
}

git_pull() {
  echo "🔄 Fetching branches..."
  spinner git fetch -p -q 

  base_branch=$(git_select_base_branch | tee /dev/tty) || exit 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi

  echo "✅ Selected base branch: $base_branch"
  base_branch="${base_branch#remotes/origin/}"

  echo "🔄 Pulling from '$base_branch'"
  spinner git pull origin "$base_branch"
}


git_checkout() {
  echo "Discovering branches..."
  git fetch --no-tags --quiet
  
  remote_branches=$(git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##')
  selected_branch=$( (git branch --format="%(refname:short)"; echo "$remote_branches") | sort -u | default_fzf)
  
  [[ -z "$selected_branch" ]] && echo "No branch selected." && return
  echo "You selected branch: $selected_branch"
  history -s "git checkout $selected_branch"
  git checkout "$selected_branch" && echo "Checkout successful" || echo "Checkout failed."
}

gc() { 
  gcheckout
}

gclean() {
  git fetch -p && for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do git branch -D $branch; done
}

# --- Upstream branch creation -----------------------------------------------
# NOTE: create_upstream_branch calls create_pr_bitbucket, which lives in your
# other file alongside pr/pra. As long as both files are sourced into the
# same shell session, this works without any extra wiring.

# Asks (via fzf yes/no) whether to switch back to a given branch, and does so
# if confirmed. Used after PR-opening flows so you can easily hop back to
# whatever you were working on before.
prompt_switch_back() {
  local target_branch="$1"
  [[ -z "$target_branch" ]] && return 0

  local go_back
  go_back=$(printf "yes\nno" | default_fzf --prompt="Switch back to '$target_branch'? > ")

  if [[ "$go_back" == "yes" ]]; then
    git checkout "$target_branch"
    echo "🔀 Switched back to '$target_branch'."
  fi
}

# Creates a branch named "upstream-<basebranchname>" off a selected base
# branch, pushes it with tracking set up, and opens a PR against a separately
# selected upstream/target branch.
create_upstream_branch() {
  local previous_branch
  previous_branch=$(git rev-parse --abbrev-ref HEAD)
  echo "debugging previous_branch $previous_branch"

  echo "🔄 Fetching branches..."
  spinner git fetch -p -q

  echo "Selecting base branch..."
  local base_branch
  base_branch=$(git_select_base_branch | tee /dev/tty) || return 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi
  base_branch="${base_branch#remotes/origin/}"
  echo "✅ Selected base branch: $base_branch"

  echo "Selecting upstream branch..."
  local upstream_branch
  upstream_branch=$(git_select_upstream_branch | tee /dev/tty) || return 1
  if [[ -z "$upstream_branch" ]]; then
    echo "❌ No upstream branch selected."
    return 1
  fi
  upstream_branch="${upstream_branch#remotes/origin/}"
  echo "✅ Selected upstream branch: $upstream_branch"

  if [[ "$upstream_branch" == "$base_branch" ]]; then
    echo "❌ Upstream branch cannot be the same as the base branch."
    return 1
  fi

  # Sanitize the base branch name (slashes -> dashes) so it's a valid
  # single-segment branch name, e.g. release/2.3 -> upstream-release-2.3
  local sanitized_base="${base_branch//\//-}"
  local new_branch="upstream-${sanitized_base}"

  local existing_branch
  existing_branch=$(git branch -a --sort=-committerdate | sed 's/^[* ]*//' | grep -F "$new_branch" | sort -u)

  if [[ -n "$existing_branch" ]]; then
    echo "⚠️  Found existing branch(es) containing '$new_branch':"
    echo "$existing_branch"

    local choice
    choice=$(printf "Use existing\nCreate new" | default_fzf --prompt="Branch already exists. What do you want to do? > ")

    if [[ "$choice" == "Use existing" ]]; then
      git stash
      echo "🔀 Checking out existing branch: $new_branch"
      git checkout "$new_branch"
      apply_stash
      echo "✅ Switched to existing branch."
      create_pr_bitbucket "$new_branch" "$upstream_branch"
      prompt_switch_back "$previous_branch"
      return 0
    fi
  fi

  echo "🚀 Creating branch '$new_branch' from '$base_branch'..."
  git stash
  git checkout "$base_branch" && git pull origin "$base_branch"
  git checkout -b "$new_branch"

  echo "📤 Pushing '$new_branch' and setting up tracking reference..."
  if ! git push -u origin "$new_branch"; then
    echo "❌ Push failed."
    # apply_stash
    return 1
  fi

  # apply_stash
  echo "✅ Branch '$new_branch' created, pushed, and tracking origin/$new_branch."

  create_pr_bitbucket "$new_branch" "$upstream_branch"
  echo "prompt_switch_back"

  prompt_switch_back "$previous_branch"
}
