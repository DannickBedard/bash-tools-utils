#!/usr/bin/env bash

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

# load fzf
source ~/bash_utils/spinner.sh
source ~/bash_utils/fzf.sh

source ~/bash_utils/project.sh

# create pr for bitbucket
source ~/bash_utils/bitbucket.sh

# git helper functions
source ~/bash_utils/git.sh


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
  nvim "~/.bashrc"
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
