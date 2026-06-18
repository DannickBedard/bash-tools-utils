#!/usr/bin/env bash

# Builds and opens a Bitbucket "create pull request" URL.
#   $1 = source branch (defaults to current branch if empty)
#   $2 = destination branch (required)
create_pr_bitbucket() {
  local source_branch="$1"
  local dest_branch="$2"

  if [[ -z "$source_branch" ]]; then
    source_branch=$(git rev-parse --abbrev-ref HEAD)
  fi

  if [[ -z "$dest_branch" ]]; then
    echo "❌ No destination branch provided." >&2
    return 1
  fi

  dest_branch="${dest_branch#remotes/origin/}"

  local bitbucket_url="https://bitbucket.org"
  local remote_url repo_info repo_owner repo_name pr_url

  remote_url=$(git remote get-url origin)
  repo_info=$(echo "$remote_url" | sed -E 's#.*/([^/]+)/([^/]+)(\.git)?$#\1 \2#')
  repo_owner=$(echo "$repo_info" | awk '{print $1}')
  repo_name=$(echo "$repo_info" | awk '{print $2}' | sed 's/\.git$//')

  pr_url="$bitbucket_url/$repo_owner/$repo_name/pull-requests/new?source=$source_branch&dest=$dest_branch"

  echo "🔗 Opening: $pr_url"
  command -v start &>/dev/null && start "$pr_url" || echo "📋 Please open manually: $pr_url"
}

pr() {
  pra
}

pra() {
  local base_branch
  base_branch=$(git_select_base_branch | tee /dev/tty) || return 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi

  echo "✅ Selected base branch: $base_branch"
  base_branch="${base_branch#remotes/origin/}"

  create_pr_bitbucket "" "$base_branch"
}
