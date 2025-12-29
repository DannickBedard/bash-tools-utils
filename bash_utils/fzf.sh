#!/bin/bash

# Lazy-load fzf only when needed
load_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
}


default_fzf() {
fzf --border --height=20% --info=inline --reverse \
        --with-nth=1 \
        --preview 'ls -lah "$(echo {} | cut -f2)" 2>/dev/null | head -20' \
        --preview-window=right:40%
}

