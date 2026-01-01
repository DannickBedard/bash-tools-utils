#!/usr/bin/env bash

pr() {
  pra
}

pra() {

  base_branch=$(gitselectbase | tee /dev/tty) || exit 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi

  echo "✅ Selected base branch: $base_branch"

  # base_branch="${base_branch#remotes/origin/}"

  # [[ -z "$selected_branch" ]] && echo "No branch selected." && return
  
  BITBUCKET_URL="https://bitbucket.org"
  REMOTE_URL=$(git remote get-url origin)
  REPO_INFO=$(echo "$REMOTE_URL" | sed -E 's#.*/([^/]+)/([^/]+)(\.git)?$#\1 \2#')
  REPO_OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
  REPO_NAME=$(echo "$REPO_INFO" | awk '{print $2}' | sed 's/\.git$//')
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  PR_URL="$BITBUCKET_URL/$REPO_OWNER/$REPO_NAME/pull-requests/new?source=$CURRENT_BRANCH&dest=$base_branch"
  
  echo "Opening: $PR_URL"
  command -v start &>/dev/null && start "$PR_URL" || echo "Please open manually: $PR_URL"
}
