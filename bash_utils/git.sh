#!/usr/bin/env bash

create_branch_from_ticket() {

  local prefix="BSP"   # default prefix
  local ticket_input=""

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

  echo "🔄 Fetching branches..."
  spinner git fetch -p >/dev/null 2>&1

  # Check if any branch already contains the ticket number
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

  read -rp "📝 Enter suffixes (optionnal e.g. v1)" description

  local new_branch="${branch_type}/${ticket_number}"
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

  local all_branches_shown=false
  # Pick from filtered or full list
  if [[ -n "$release_hotfix_list" ]]; then
    base_branch=$(printf "%s\n" "$release_hotfix_list" \
      | default_fzf --prompt="Select base branch (release/hotfix): ")
  else
    all_branches_shown=true
    echo "📦 No release/hotfix branches found, showing all branches." >&2
    base_branch=$(printf "%s\n" "$branch_list" \
      | default_fzf --prompt="Select base branch (all): " --reverse)
  fi

  if [[ "$all_branches_shown" == true ]]; then
    echo "❌ No base branch selected." >&2
    return 1
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
  show_stash=$(printf "yes\nno\napply\nskip" | default_fzf prompt="Show stash?  > ")

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
        return 1
      fi

      # ask to apply stash.
      local apply_stash
      apply_stash=$(printf "yes\nno\nskip" | default_fzf --prompt="Apply stash?  > ")

      if [ "$apply_stash" == "skip" ]; then
        skip_stash
      fi

      if [[ -n "$apply_stash" ]]; then
        if [ "$apply_stash" == "yes" ]; then
          echo "📦 Restoring stash..."
          restore_stash
          return 1
        fi
      fi

  fi

  if [ "$show_stash" == "apply" ]; then
    echo "📦 Applying stash..."
    git stash pop
    return 1
  fi
}

gcheckout() {
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
