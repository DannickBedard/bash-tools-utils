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

  # Fetch first so remote-only branches are part of the existing-branch check
  echo "🔄 Fetching branches..."
  spinner git fetch -p -q

  local existing_branch choice suffix suffix_asked=false
  while existing_branch=$(_find_ticket_branches "$ticket_number"); [[ -n "$existing_branch" ]]; do
    echo "⚠️  Found existing branch(es) for '$ticket_number':"
    echo "$existing_branch"

    choice=$(printf "Use existing\nCreate new" | default_fzf --prompt="Branch already exists. What do you want to do? > ")

    case "$choice" in
      "Use existing")
        local selected_existing
        selected_existing=$(echo "$existing_branch" | default_fzf --prompt="Select existing branch > ")
        if [[ -z "$selected_existing" ]]; then
          echo "❌ No branch selected."
          return 1
        fi
        local stashed=false
        _stash_if_dirty && stashed=true
        echo "🔀 Checking out existing branch: $selected_existing"
        git checkout "$selected_existing" && echo "✅ Switched to existing branch."
        $stashed && apply_stash
        return 0
        ;;
      "Create new")
        read -rp "📝 Enter suffixes (optionnal e.g. v1) : " suffix
        suffix_asked=true
        # No suffix: keep the name, the exact-name check below catches a real clash
        [[ -z "$suffix" ]] && break
        ticket_number="$ticket_number-$(_slugify "$suffix")"
        echo "branch name: $ticket_number"
        ;;
      *)
        echo "❌ Cancelled."
        return 1
        ;;
    esac
  done

  echo "Selecting base branch..."
  local base_branch
  base_branch=$(git_select_base_branch | tee /dev/tty) || return 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi

  base_branch="${base_branch#remotes/origin/}"
  echo "✅ Selected base branch: $base_branch"

  local branch_type
  branch_type=$(printf "bugfix\nfeature" | default_fzf --prompt="Select branch type > ")
  if [[ -z "$branch_type" ]]; then
    echo "❌ No branch type selected."
    return 1
  fi

  local new_branch="${branch_type}/${ticket_number}"
  if ! $suffix_asked; then
    read -rp "📝 Enter suffixes (optionnal e.g. v1) : " suffix
    [[ -n "$suffix" ]] && new_branch="${new_branch}-$(_slugify "$suffix")"
  fi

  if git show-ref --quiet "refs/heads/$new_branch" || git show-ref --quiet "refs/remotes/origin/$new_branch"; then
    echo "❌ Branch '$new_branch' already exists. Run again and pick a suffix."
    return 1
  fi

  echo "🚀 Creating branch '$new_branch' from '$base_branch'..."
  local stashed=false
  _stash_if_dirty && stashed=true
  if ! { git checkout "$base_branch" && git pull origin "$base_branch"; }; then
    echo "❌ Could not update '$base_branch', branch not created."
    $stashed && apply_stash
    return 1
  fi
  git checkout -b "$new_branch" && echo "✅ Branch created and switched: $new_branch"
  $stashed && apply_stash
}

# Local and remote branches for a ticket, newest first, without duplicates.
# Matches the whole ticket number: BSP-1418 does not match BSP-14182.
_find_ticket_branches() {
  git branch -a --sort=-committerdate --format='%(refname:short)' \
    | sed 's#^origin/##' \
    | grep -vx 'origin\|HEAD' \
    | grep -E "(^|/)$1([^0-9]|$)" \
    | awk '!seen[$0]++'
}

# Stash only when there is something to stash; returns 1 when the tree is clean,
# so callers don't pop an older, unrelated stash afterwards.
_stash_if_dirty() {
  git diff --quiet && git diff --cached --quiet && return 1
  git stash
}

_slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

git_select_base_branch() {
  local base_branch branch_list release_hotfix_list

  # Get all branches once
  branch_list=$(git branch --all --format='%(refname:short)' \
    | sed 's#^origin/##' \
    | grep -vx 'origin\|HEAD' \
    | sort -u)

  # Extract only release/hotfix branches
  release_hotfix_list=$(printf "%s\n" "$branch_list" | grep -E '^(release|hotfix)/' || true)

  # Release/hotfix list first; cancelling it falls back to the full list once
  if [[ -n "$release_hotfix_list" ]]; then
    base_branch=$(printf "%s\n" "$release_hotfix_list" \
      | default_fzf --prompt="Select base branch (release/hotfix): ")
    if [[ -n "$base_branch" ]]; then
      echo "$base_branch"
      return 0
    fi
    echo "📦 No release/hotfix branch chosen, showing all branches." >&2
  else
    echo "📦 No release/hotfix branches found, showing all branches." >&2
  fi

  base_branch=$(printf "%s\n" "$branch_list" \
    | default_fzf --prompt="Select base branch (all): ")

  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected." >&2
    return 1
  fi

  echo "$base_branch"
}

git_stash_show() {
  apply_stash
}

# Interactive restore of the latest stash. Every "skip"/"no"/Esc stops here.
apply_stash() {
  if [[ -z "$(git stash list -n 1)" ]]; then
    echo "📦 No stash to restore."
    return 0
  fi

  local answer
  answer=$(printf "yes\nno\napply\nskip" | default_fzf --prompt="Show stash?  > ")
  case "$answer" in
    apply) _restore_stash; return ;;
    yes)   echo "📦 Showing stash..."; git stash show ;;
    *)     echo "Skipping stash recup..."; return 0 ;;
  esac

  answer=$(printf "yes\nno\napply\nskip" | default_fzf --prompt="Show detail?  > ")
  case "$answer" in
    apply) _restore_stash; return ;;
    yes)   echo "📦 Showing detail..."; git stash show --patch ;;
    no)    ;;
    *)     echo "Skipping stash recup..."; return 0 ;;
  esac

  answer=$(printf "yes\nno" | default_fzf --prompt="Apply stash?  > ")
  if [[ "$answer" == "yes" ]]; then
    _restore_stash
  else
    echo "Skipping stash recup... (still in git stash list)"
  fi
}

_restore_stash() {
  echo "📦 Restoring stash..."
  git stash pop
}

git_pull() {
  echo "🔄 Fetching branches..."
  spinner git fetch -p -q

  local base_branch
  base_branch=$(git_select_base_branch | tee /dev/tty) || return 1
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
  git_checkout
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
# whatever you were working on before. Pass "true" as 2nd argument when
# changes were stashed before leaving that branch, to offer restoring them.
prompt_switch_back() {
  local target_branch="$1" stashed="${2:-false}"
  [[ -z "$target_branch" ]] && return 0

  local go_back
  go_back=$(printf "yes\nno" | default_fzf --prompt="Switch back to '$target_branch'? > ")

  if [[ "$go_back" == "yes" ]]; then
    git checkout "$target_branch" || return 1
    echo "🔀 Switched back to '$target_branch'."
    $stashed && apply_stash
  elif $stashed; then
    echo "📦 Your changes from '$target_branch' are still in git stash list."
  fi
}

# Creates a branch named "upstream-<basebranchname>" off a selected base
# branch, pushes it with tracking set up, and opens a PR against a separately
# selected upstream/target branch.
create_upstream_branch() {
  local previous_branch
  previous_branch=$(git rev-parse --abbrev-ref HEAD)

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
  upstream_branch=$(git_select_base_branch | tee /dev/tty) || return 1
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

  # Exact name only: upstream-release-v2026.4 must not match upstream-release-v2026.4-13.
  # The remote copy is overwritten by the force push, only the local one is in the way.
  local recreate=false
  if git show-ref --quiet "refs/heads/$new_branch"; then
    echo "⚠️  Local branch '$new_branch' already exists."
    local choice
    choice=$(printf "Clean and recreate\nCancel" | default_fzf --prompt="Branch already exists. What do you want to do? > ")
    if [[ "$choice" != "Clean and recreate" ]]; then
      echo "❌ Cancelled."
      return 1
    fi
    recreate=true
  fi

  local stashed=false
  _stash_if_dirty && stashed=true

  echo "🚀 Creating branch '$new_branch' from '$base_branch'..."
  if ! { git checkout "$base_branch" && git pull origin "$base_branch"; }; then
    echo "❌ Could not update '$base_branch'."
    prompt_switch_back "$previous_branch" "$stashed"
    return 1
  fi

  # Now off the branch, so it can be deleted even if we started on it
  $recreate && git branch -D "$new_branch"

  if ! git checkout -b "$new_branch"; then
    echo "❌ Could not create '$new_branch'."
    prompt_switch_back "$previous_branch" "$stashed"
    return 1
  fi

  if ! git pull origin "$upstream_branch"; then
    echo "❌ Pulling '$upstream_branch' into '$new_branch' failed (conflicts?). Resolve, then push and open the PR yourself."
    $stashed && echo "📦 Your changes from '$previous_branch' are still in git stash list."
    return 1
  fi

  echo "📤 Pushing '$new_branch' and setting up tracking reference..."
  if ! git push -f -u origin "$new_branch"; then
    echo "❌ Push failed."
    prompt_switch_back "$previous_branch" "$stashed"
    return 1
  fi

  echo "✅ Branch '$new_branch' created, pushed, and tracking origin/$new_branch."

  create_pr_bitbucket "$new_branch" "$upstream_branch"

  prompt_switch_back "$previous_branch" "$stashed"
}
