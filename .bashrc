# Start timing bashrc load
_bashrc_start_time=$(date +%s%N)

# Lazy-load NVM only when needed
load_nvm() {
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  fi
  if [ -s "$NVM_DIR/bash_completion" ]; then
    . "$NVM_DIR/bash_completion"
  fi
}

export NVM_DIR="$HOME/.nvm"

# Wrap nvm, node, and npm commands safely (lazy-load)
alias nvm='load_nvm; command nvm'
alias node='load_nvm; command node'
alias npm='load_nvm; command npm'

# History settings
HISTSIZE=500  
HISTFILESIZE=100000

# Lazy-load fzf only when needed
load_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
}


# Projects array - declare once at startup
declare -A projects=(
  ["viridem"]="/c/viridem_v3/viridem"
  ["viridemjs"]="/c/viridem_v3/viridem/web/js"
  ["export api"]="/c/projects/viridem-api-export-test"
  ["aiCommService"]="/c/projects/aicommservice"
  ["aiService"]="/c/projects/aiservice"
  ["viridemConnect"]="/c/ViridemConnect"
  ["nvimConfig"]="/c/Users/dannick.bedard/AppData/Local/nvim"
  ["nvimPlugin"]="/c/Users/dannick.bedard/AppData/Local/nvim-local"
  ["userConfig"]="/c/Users/dannick.bedard"
  ["notes"]="/c/Users/dannick.bedard/Documents/Notes"
  ["devTemp"]="/c/Users/dannick.bedard/Documents/Temp/test/dev"
  ["local project"]="/c/projects/"
  ["canlak"]="/c/projects/canlak"
  ["junitJava"]="/c/projects/viridem-junit"
  ["glazemw"]="/c/Users/dannick.bedard/.glzr"
  ["wezterm"]="/c/Users/dannick.bedard/wezterm-config"
  ["keyboard"]="/c/Users/dannick.bedard/Documents/katana-config"
  ["formula viridem"]="/c/projects/viridem-formula"
)

# Project navigation functions
list_projects() {
  for name in "${!projects[@]}"; do
    echo "$name -> ${projects[$name]}"
  done
}

go_to_project() {
  local project_name="$1"
  if [[ -n "${projects[$project_name]}" ]]; then
    cd "${projects[$project_name]}" || echo "Failed to navigate to ${projects[$project_name]}"
    echo "Now in $(pwd)"
  else
    echo "Project '$project_name' not found!"
  fi
}

op() {
  load_fzf
  local selected_project
  # Pass path after the project name separated by tab
  selected_project=$(for name in "${!projects[@]}"; do
    printf "%s\t%s\n" "$name" "${projects[$name]}"
  done | fzf --border --height=20% --info=inline --reverse \
        --with-nth=1 \
        --preview 'ls -lah "$(echo {} | cut -f2)" 2>/dev/null | head -20' \
        --preview-window=right:40% | cut -f1)
  [[ -n "$selected_project" ]] && go_to_project "$selected_project"
}

opv() {
  load_fzf
  local selected_project
  selected_project=$(for name in "${!projects[@]}"; do
    printf "%s\t%s\n" "$name" "${projects[$name]}"
  done | fzf --border --height=20% --info=inline --reverse \
        --with-nth=1 \
        --preview 'ls -lah "$(echo {} | cut -f2)" 2>/dev/null | head -20' \
        --preview-window=right:40% | cut -f1)
  if [[ -n "$selected_project" ]]; then
    go_to_project "$selected_project" && nvim .
  fi
}

# Git functions
pr() {
  pra
}

pra() {
  load_fzf

  base_branch=$(gitselectbase | tee /dev/tty) || exit 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi

  echo "✅ Selected base branch: $base_branch"

  # base_branch="${base_branch#remotes/origin/}"

  # selected_branch=$(git branch --all | sed 's/^[* ]*//' | sed 's#^remotes/origin/##' | sort -u | grep -E '^(release|hotfix)/' | fzf --border --height=20% --info=inline --reverse)
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

work() {
  load_fzf

  local prefix="BSP"   # default prefix
  local ticket_input=""

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prefix)
        prefix="$2"
        shift 2
        ;;
      *)
        ticket_input="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$ticket_input" ]]; then
    echo "❌ Usage: work [-p <prefix>] <ticket-number | jira-url>"
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
  if [[ ! "$ticket_number" =~ ^${prefix}- ]]; then
    ticket_number="${prefix}-${ticket_number}"
  fi

  echo "🔄 Fetching branches..."
  git fetch -p >/dev/null 2>&1

  # Check if any branch already contains the ticket number
  local existing_branch
  existing_branch=$(git branch -a --sort=-committerdate | sed 's/^[* ]*//' | grep -F "$ticket_number" | sort -u)

  if [[ -n "$existing_branch" ]]; then
    echo "⚠️  Found existing branch(es) containing '$ticket_number':"
    echo "$existing_branch"

    local choice
    choice=$(printf "Use existing\nCreate new" | fzf --prompt="Branch already exists. What do you want to do? > " --height=10% --info=inline --border --reverse)

    if [[ "$choice" == "Use existing" ]]; then
      local selected_existing
      selected_existing=$(echo "$existing_branch" | fzf --prompt="Select existing branch > " --height=20% --info=inline --border --reverse)
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
  base_branch=$(gitselectbase | tee /dev/tty) || exit 1
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected."
    return 1
  fi
  echo "✅ Selected base branch: $base_branch"
  base_branch="${base_branch#remotes/origin/}"

  local branch_type
  branch_type=$(printf "bugfix\nfeature" | fzf --prompt="Select branch type > " --height=20% --info=inline --border --reverse)
  if [[ -z "$branch_type" ]]; then
    echo "❌ No branch type selected."
    return 1
  fi

  read -rp "📝 Enter short description (e.g. add-login-api): " description

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

gitselectbase() {
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
      | fzf --border --height=20% --info=inline --prompt="Select base branch (release/hotfix): " --reverse)
  else
    echo "📦 No release/hotfix branches found, showing all branches." >&2
    base_branch=$(printf "%s\n" "$branch_list" \
      | fzf --border --height=20% --info=inline --prompt="Select base branch (all): " --reverse)
  fi

  # No selection case
  if [[ -z "$base_branch" ]]; then
    echo "❌ No base branch selected." >&2
    return 1
  fi

  # Return value by echoing it
  echo "$base_branch"
}

apply_stash() {
  # ask to show stash or not
  local show_stash
  show_stash=$(printf "yes\nno\napply\nskip" | fzf --prompt="Show stash?  > " --height=20% --info=inline --border)

  if [[ -n "$show_stash" ]]; then

    if [ "$show_stash" == "skip" ]; then
      echo "Skipping stash recup..."
      return 1
    fi

    if [ "$show_stash" == "yes" ]; then
      echo "📦 Showing stash..."
      git stash show

      # ask to see more detail or apply stash
      local show_detail
      show_detail=$(printf "yes\nno\napply\nskip" | fzf --prompt="Show detail?  > " --height=20% --info=inline --border)

      if [ "$show_detail" == "skip" ]; then
        echo "Skipping stash recup..."
        return 1
      fi
      if [[ -n "$show_detail" ]]; then
        if [ "$show_detail" == "yes" ]; then
          echo "📦 Showing detail..."
          git stash show --patch
        fi
      fi
      if [ "$show_detail" == "apply" ]; then
        echo "📦 Applying stash..."
        git stash pop
        return 1
      fi

      # ask to apply stash.
      local apply_stash
      apply_stash=$(printf "yes\nno\nskip" | fzf --prompt="Apply stash?  > " --height=20% --info=inline --border)

      if [ "$apply_stash" == "skip" ]; then
        echo "Skipping stash recup..."
        return 1
      fi

      if [[ -n "$apply_stash" ]]; then
        if [ "$apply_stash" == "yes" ]; then
          echo "📦 Restoring stash..."
          git stash pop
        return 1
        fi
      fi

    fi
    if [ "$show_stash" == "apply" ]; then
      echo "📦 Applying stash..."
      git stash pop
      return 1
    fi
  fi
}

gcheckout() {
  load_fzf
  echo "Discovering branches..."
  git fetch --no-tags --quiet
  
  remote_branches=$(git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##')
  selected_branch=$( (git branch --format="%(refname:short)"; echo "$remote_branches") | sort -u | fzf --border --height=20% --info=inline --reverse)
  
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

# Utility functions
sf() {
  echo "Sourcing .bashrc"
  source ~/.bashrc
}

vim() {
  command nvim .
}

vl() {
  local folder="${projects["viridem"]}/logs"  
  local last_file=$(ls -t "$folder" 2>/dev/null | head -n 1)
  if [[ -n "$last_file" ]]; then
    "/c/Program Files/klogg/klogg.exe" "$(realpath "$folder/$last_file")" &
  else
    echo "No files found in $folder"
  fi
}

vll() {
  local folder="${projects["viridem"]}/api/storage/logs"  
  local last_file=$(ls -t "$folder" 2>/dev/null | grep laravel- | head -n 1)
  if [[ -n "$last_file" ]]; then
    "/c/Program Files/klogg/klogg.exe" "$(realpath "$folder/$last_file")" &
  else
    echo "No files found in $folder"
  fi
}

vul() {
  local folder="${projects["viridem"]}/logs"  
  local update_log_file="viridem.update.log"
  if [[ -f "$folder/$update_log_file" ]]; then
    "/c/Program Files/klogg/klogg.exe" "$(realpath "$folder/$update_log_file")" &
  else
    echo "File not found: $folder/$update_log_file"
  fi
}

config() {
  nvim "/c/Users/dannick.bedard/.bashrc"
}

vconfig() {
  nvim "${projects["nvimConfig"]}"
}

note() {
  cd "${projects["notes"]}" && nvim .
}

vm() {
  ssh root@10.12.0.64
}

qa1() {
  ssh root@qa.viridem.ca
}

qa2() {
  ssh root@qa2.viridem.ca
}

qa3() {
  ssh root@10.20.0.45
}

h() {
  echo ""
  echo "===== Dannick's Bash Functions Help ====="
  echo ""
  echo "PROJECT NAVIGATION:"
  echo "  list_projects    - List all defined projects and their paths"
  echo "  go_to_project    - Navigate to a specific project directory"
  echo "  op               - Open project (select with fuzzy finder)"
  echo "  opv              - Open project in Neovim (select and open)"
  echo ""
  echo "GIT WORKFLOWS:"
  echo "  work 1234        - Get started working on ticket (will create the branch from the int or string or url)"
  echo "  pr               - Create pull request (release branches)"
  echo "  pra              - Create pull request (all branches)"
  echo "  gcheckout        - Fetch and checkout branch using fuzzy finder"
  echo "  gc               - Shortcut for gcheckout"
  echo "  gclean           - Remove local branches deleted from remote"
  echo ""
  echo "LOG VIEWING:"
  echo "  vl               - Open most recent Viridem log with klogg"
  echo "  vll              - Open Laravel log with klogg"
  echo "  vul              - Open Viridem update log with klogg"
  echo ""
  echo "SSH SHORTCUTS:"
  echo "  vm, qa1, qa2, qa3 - SSH to various servers"
  echo ""
  echo "MISCELLANEOUS:"
  echo "  sf               - Source ~/.bashrc file"
  echo "  h                - Display this help menu"
  echo "  config           - Edit .bashrc"
  echo "  vconfig          - Edit Neovim config"
  echo "  note             - Open notes"
  echo "  bsp, si          - Open Jira tickets"
  echo "  rmap             - Start kanata config"
  echo ""
}

bsp() {
  if [ -z "$1" ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    number=$(echo "$CURRENT_BRANCH" | grep -o '[0-9]\+')
    ticket="BSP-$number"
  else
    ticket="BSP-$1"
  fi
  url="https://jiraloginnove.atlassian.net/browse/$ticket"
  start "" "$url"
}

si() {
  if [ -z "$1" ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    number=$(echo "$CURRENT_BRANCH" | grep -o '[0-9]\+')
    ticket="SI-$number"
  else
    ticket="SI-$1"
  fi
  url="https://jiraloginnove.atlassian.net/browse/$ticket"
  start "" "$url"
}

ni() {
  local viridemProjectPath="${projects["viridem"]}"
  if [[ "$PWD" == *"$viridemProjectPath"* ]]; then
    cd "$viridemProjectPath/web/js" && npm i
  else
    npm i
  fi
}

nb() {
  local viridemProjectPath="${projects["viridem"]}"
  if [[ "$PWD" == *"$viridemProjectPath"* ]]; then
    cd "$viridemProjectPath/web/js" && npm run build
  else
    npm run build
  fi
}

nw() {
  local viridemProjectPath="${projects["viridem"]}"
  if [[ "$PWD" == *"$viridemProjectPath"* ]]; then
    cd "$viridemProjectPath/web/js" && npm run watch
  else
    npm run watch
  fi
}

viridemRmUpdate() {
  rm /c/viridem_v3/app/data/.viridemUpdate.lock
}

rmap() {
  cd /c/Users/dannick.bedard/Documents/katana-config && ./kanata.exe --cfg ./kanata.kbd
}

# End timing and display bashrc load time
_bashrc_end_time=$(date +%s%N)
_bashrc_load_time=$(( (_bashrc_end_time - _bashrc_start_time) / 1000000 ))
echo "✓ Bashrc loaded in ${_bashrc_load_time}ms"
unset _bashrc_start_time _bashrc_end_time _bashrc_load_time
