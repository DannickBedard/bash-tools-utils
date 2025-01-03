
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"

# Declare an associative array to store project names and their paths
declare -A projects

# Populate the projects array with names and locations
projects=(
    ["viridem"]="/c/viridem"
    ["viridem api"]="/c/viridem/api"
    ["export api"]="/c/project/viridem-api-export-test"
    ["viridemConnect"]="/c/ViridemConnect"
    ["nvim"]="/c/Users/Dannick.bedard/AppData/Local/nvim"
)

# Function to list all projects
list_projects() {
    for name in "${!projects[@]}"; do
        echo "$name -> ${projects[$name]}"
    done
}

# Function to navigate to a project directory by name
go_to_project() {
    local project_name="$1"
    if [[ -n "${projects[$project_name]}" ]]; then
        cd "${projects[$project_name]}" || echo "Failed to navigate to ${projects[$project_name]}"
        echo "Now in $(pwd)"
    else
        echo "Project '$project_name' not found!"
    fi
}

# Function to use fzf for project selection
op() {
    local selected_project=$(for name in "${!projects[@]}"; do echo "$name"; done | fzf)
    if [[ -n "$selected_project" ]]; then
        go_to_project "$selected_project"
    else
        echo "No project selected."
    fi
}
