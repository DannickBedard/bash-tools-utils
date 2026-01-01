#!/usr/bin/env bash

# Lazy-load fzf only when needed
load_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
}

alias npm='load_fzf; command fzf'

default_fzf() {
  load_fzf
  fzf --border --height=20% --info=inline --reverse 
    #--with-nth=1 \
    #--preview-window=right:40%

}

