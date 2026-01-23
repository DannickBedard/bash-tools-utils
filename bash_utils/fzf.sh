#!/usr/bin/env bash

require_fzf() {
  if [[ -z "$(command -v fzf)" ]]; then
    echo "Error: fzf is required but not installed."
    echo "Install fzf to use this function."
    return 1
  fi
}

# Lazy-load fzf only when needed
load_fzf() {
  require_fzf
  if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
}

alias npm='load_fzf; command fzf'

default_fzf() {
  require_fzf
  load_fzf
  fzf --border --height=20% --info=inline --reverse 
    #--with-nth=1 \
    #--preview-window=right:40%

}

