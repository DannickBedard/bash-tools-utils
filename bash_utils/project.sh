#!/usr/bin/env bash

# Get project defined in .bash_projects.json
PROJECTS_FILE="$HOME/bash_projects.json"

load_projects() {
  unset projects
  declare -gA projects

  if [[ ! -f "$PROJECTS_FILE" ]]; then
    echo "Projects file not found: $PROJECTS_FILE"
    return 1
  fi

  while IFS= read -r line; do
    # Match: "key": "value"
    if [[ $line =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      projects["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done < "$PROJECTS_FILE"
}

load_projects # load the projects from json file

refresh_projects() {
  echo "🔄 Reloading projects..."

  if load_projects; then
    echo "✅ Projects reloaded ($((${#projects[@]})) entries)"
  else
    echo "❌ Failed to reload projects"
    return 1
  fi
}

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
  local selected_project
  # Pass path after the project name separated by tab
  selected_project=$(for name in "${!projects[@]}"; do
    printf "%s\t%s\n" "$name" "${projects[$name]}"
  done | default_fzf | cut -f1)
  [[ -n "$selected_project" ]] && go_to_project "$selected_project"
}

opv() {
  local selected_project
  selected_project=$(for name in "${!projects[@]}"; do
    printf "%s\t%s\n" "$name" "${projects[$name]}"
  done | default_fzf | cut -f1)
  if [[ -n "$selected_project" ]]; then
    go_to_project "$selected_project" && nvim .
  fi
}

require_jq() {
  if [[ -z "$(command -v jq)" ]]; then
    echo "Error: jq is required but not installed."
    echo "Install jq to use this function."
    return 1
  fi
}

add_project() {
   require_jq
  local name="$1"
  local path="${2:-$(pwd)}"
  local file="${PROJECTS_FILE}"

  # ---- validation ----
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed" >&2
    return 1
  fi

  if [ -z "$name" ]; then
    echo "Usage: add_project <name> [path]" >&2
    return 1
  fi

  # ---- setup ----
  mkdir -p "$(dirname "$file")"

  # Normalize path
  path="$(cd "$path" && pwd)"

  # Initialize file if missing or empty
  if [ ! -s "$file" ]; then
    echo '{}' >"$file"
  fi

 # ---- update json (WRITE IT BACK) ----
  tmp="$(mktemp)"

  if ! jq --arg name "$name" --arg path "$path" \
        '.[$name] = $path' \
        "$file" >"$tmp"; then
    echo "Error: jq failed" >&2
    rm -f "$tmp"
    return 1
  fi

  mv "$tmp" "$file"

  echo "✓ Project '$name' → $path"
  refresh_projects
}

 remove_project() {
   require_jq
  local name="$1"
  local file="$PROJECTS_FILE"
  local tmp

  if [ -z "$name" ]; then
    echo "Usage: remove_project <name>" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required" >&2
    return 1
  fi

  if [ ! -f "$file" ]; then
    echo "Projects file not found: $file" >&2
    return 1
  fi

  # Check existence
  if ! jq -e --arg name "$name" 'has($name)' "$file" >/dev/null; then
    echo "Project '$name' not found" >&2
    return 1
  fi

  tmp="$(mktemp)"

  if ! jq --arg name "$name" \
        'del(.[$name])' \
        "$file" >"$tmp"; then
    echo "Error: jq failed" >&2
    rm -f "$tmp"
    return 1
  fi

  mv "$tmp" "$file"

  echo "🗑️  Removed project '$name'"
  refresh_projects
}

opr() {
  local selected_project confirm

  selected_project=$(for name in "${!projects[@]}"; do
    printf "%s\t%s\n" "$name" "${projects[$name]}"
  done | default_fzf | cut -f1)

  [[ -z "$selected_project" ]] && return 0

  echo "Delete project '$selected_project'?"
  read -r -p "[y/N] " confirm

  case "$confirm" in
    y|Y)
      remove_project "$selected_project"
      ;;
    *)
      echo "❌ Cancelled"
      ;;
  esac
}


