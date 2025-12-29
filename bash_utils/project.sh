#!/bin/bash

# Get project defined in .bash_projects.json
PROJECTS_FILE="$HOME/.bash_projects.json"

load_projects() {
  [[ -v projects ]] && unset projects
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

