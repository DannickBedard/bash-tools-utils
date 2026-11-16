#!/usr/bin/env bash
# Viridem worktrees without Claude. The add/base functions wrap the viridem-worktree kit scripts
# (~/.claude/skills/viridem-worktree), so the logic stays in one place; removal and stale
# detection live here.
#
#   wt_add   [KEY|number|Jira URL] [version] [bugfix|feature]   new ticket worktree + nvim tab
#   wt_base  [version] [release-branch]                          create or update a base
#   wt_rm    [name...]                                           remove worktrees (branches kept)
#   wt_stale                                                     ticket worktrees merged or deleted
#   wt_clean                                                     pick stale ones and remove them

_WT_KIT="$HOME/.claude/skills/viridem-worktree"
_WT_TAB="$HOME/.claude/skills/worktree-nvim-tab/open-tab.sh"

# Sets _WT_MAIN (main clone) and _WT_ROOT (worktrees folder) from the kit .env, the file the kit
# scripts read. Runs load_env in a subshell: it calls exit on a bad line, which must not close
# this terminal.
_wt_paths() {
  local kit out main root
  kit=$(tr -d '\r\n' < "$_WT_KIT/kit-path" 2>/dev/null)
  out=$(source "$_WT_KIT/env.sh" \
    && load_env "${VIRIDEM_ENV_FILE:-$kit/.env}" \
    && printf '%s\n%s\n' "${VIRIDEM_MAIN:-}" "${VIRIDEM_WORKTREES:-}") || out=""
  main=$(sed -n 1p <<<"$out")
  root=$(sed -n 2p <<<"$out")
  if [[ -z "$main" || -z "$root" ]]; then
    echo "❌ VIRIDEM_MAIN / VIRIDEM_WORKTREES not found in the kit .env ($kit/.env)." >&2
    return 1
  fi
  _WT_MAIN=$(cygpath -u "$main"); _WT_MAIN="${_WT_MAIN%/}"
  _WT_ROOT=$(cygpath -u "$root"); _WT_ROOT="${_WT_ROOT%/}"
}

# One row per worktree of $_WT_ROOT: "name<TAB>kind<TAB>branch<TAB>base|release"
#   kind: base (follows a release branch), ticket (attached to a base) or other.
# Pure bash (read, parameter expansion): every subprocess costs tens of ms in Git Bash.
_wt_rows() {
  local dir name line g head branch meta kind
  for dir in "$_WT_ROOT"/*/; do
    dir="${dir%/}"
    [[ -f "$dir/.git" ]] || continue
    name="${dir##*/}"
    read -r line < "$dir/.git" || continue
    g="${line#gitdir: }"
    g="${g%$'\r'}"
    # C:/x/y -> /c/x/y
    [[ "$g" =~ ^([A-Za-z]):(.*)$ ]] && g="/${BASH_REMATCH[1],,}${BASH_REMATCH[2]}"
    read -r head < "$g/HEAD" || continue
    if [[ "$head" == ref:* ]]; then branch="${head#ref: refs/heads/}"; else branch="(detached ${head:0:8})"; fi
    meta="" kind=other
    if [[ -f "$g/viridem-release" ]]; then
      kind=base; read -r meta < "$g/viridem-release"
    elif [[ -f "$g/viridem-base" ]]; then
      kind=ticket; read -r meta < "$g/viridem-base"
    fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$kind" "$branch" "$meta"
  done
}

_wt_bases() { _wt_rows | awk -F'\t' '$2 == "base" { print $1 "\t" $4 }'; }

_wt_table() { column -t -s $'\t'; }

# ---------------------------------------------------------------------------------------------
# wt_add [KEY|number|Jira URL] [version] [bugfix|feature]
#   14199, BSP-14199 or https://…/browse/BSP-14199. A missing version or kind is picked in fzf.
#   Then opens the Git Bash + nvim tab on the new worktree.
wt_add() {
  _wt_paths || return 1
  local input="${1:-}" version="${2:-}" kind="${3:-}" key

  [[ -n "$input" ]] || read -rp "📝 Ticket (number, key or Jira URL): " input
  [[ -n "$input" ]] || { echo "❌ No ticket given."; return 1; }
  if [[ "$input" =~ /browse/([A-Za-z]+-[0-9]+) ]]; then key="${BASH_REMATCH[1]}"; else key="$input"; fi
  [[ "$key" =~ ^[0-9]+ ]] && key="BSP-$key"
  # BSP-1234 upper case, an optional suffix (-v2) lower case.
  [[ "$key" =~ ^([A-Za-z]+-[0-9]+)(-.*)?$ ]] || { echo "❌ $input is not a ticket (BSP-1234)."; return 1; }
  key="${BASH_REMATCH[1]^^}${BASH_REMATCH[2],,}"

  if [[ -z "$version" ]]; then
    version=$(_wt_bases | _wt_table | default_fzf --prompt="Base version for $key > " | awk '{print $1}')
    [[ -n "$version" ]] || { echo "❌ No base selected."; return 1; }
  fi
  [[ "$version" =~ ^[0-9] ]] && version="v$version"

  if [[ -z "$kind" ]]; then
    kind=$(printf "bugfix\nfeature" | default_fzf --prompt="Branch type > ")
    [[ -n "$kind" ]] || { echo "❌ No branch type selected."; return 1; }
  fi

  key=$(_wt_free_name "$key") || return 1

  bash "$_WT_KIT/new-worktree.sh" "$key" "$version" "$kind" || return 1
  echo
  bash "$_WT_TAB" "$_WT_ROOT/$key"
}

# _wt_free_name <name>: prints a worktree name whose branch and folder are free. While a branch
# <anything>/<name> exists (local or on origin) or the folder exists, shows the ticket's branches
# and asks for a suffix: BSP-1234 -> BSP-1234-v2. Prompts go to stderr (stdout is the result).
_wt_free_name() {
  local name="$1" ticket remote local_branches all suffix
  ticket="${name%%-[a-z]*}"   # BSP-1234-v2 -> BSP-1234

  echo "🔄 Checking existing branches..." >&2
  remote=$(git -C "$_WT_MAIN" ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##')
  [[ -n "$remote" ]] || echo "⚠️  Could not list origin branches: checking local ones only." >&2
  local_branches=$(git -C "$_WT_MAIN" for-each-ref --format='%(refname:short)' refs/heads)
  all=$(printf '%s\n%s\n' "$local_branches" "$remote" | sed '/^$/d' | sort -u)

  while grep -Eq "(^|/)${name}\$" <<<"$all" || [[ -e "$_WT_ROOT/$name" ]]; do
    echo "⚠️  '$name' already exists. Branches and worktrees for $ticket:" >&2
    { grep -E "(^|/)${ticket}([^0-9]|\$)" <<<"$all"
      ls -d "$_WT_ROOT/$ticket"* 2>/dev/null | sed 's#.*/#worktree: #'; } | sed 's/^/   /' >&2
    read -rp "📝 Suffix (e.g. v2, empty to cancel): " suffix
    [[ -n "$suffix" ]] || { echo "❌ Cancelled." >&2; return 1; }
    suffix=$(tr '[:upper:] ' '[:lower:]-' <<<"$suffix" | tr -cd 'a-z0-9-')
    suffix="${suffix#-}"
    [[ -n "$suffix" ]] || { echo "❌ Suffix must hold letters or digits." >&2; continue; }
    name="$ticket-$suffix"
  done
  echo "$name"
}

# ---------------------------------------------------------------------------------------------
# wt_base [version] [release-branch]
#   Existing base: update it (latest of its release branch, or move it to <release-branch>).
#   New base: pick the origin release branch in fzf, then create it.
wt_base() {
  _wt_paths || return 1
  local version="${1:-}" release="${2:-}" current choice

  if [[ -z "$version" ]]; then
    version=$({ _wt_bases | _wt_table; echo "+ new base"; } \
      | default_fzf --prompt="Base > " | awk '{print $1}')
    [[ -n "$version" ]] || { echo "❌ No base selected."; return 1; }
    if [[ "$version" == "+" ]]; then
      read -rp "📝 New version (e.g. v2026.6): " version
      [[ -n "$version" ]] || { echo "❌ No version given."; return 1; }
    fi
  fi
  [[ "$version" =~ ^[0-9] ]] && version="v$version"

  if [[ -e "$_WT_ROOT/$version" ]]; then
    if [[ -z "$release" ]]; then
      current=$(_wt_bases | awk -F'\t' -v v="$version" '$1 == v { print $2 }')
      choice=$(printf "Update to latest of %s\nMove to another release branch\n" "$current" \
        | default_fzf --prompt="$version > ")
      case "$choice" in
        Update*) ;;
        Move*) release=$(_wt_pick_release "$version") || return 1 ;;
        *) echo "❌ Cancelled."; return 1 ;;
      esac
    fi
    bash "$_WT_KIT/update-base.sh" "$version" ${release:+"$release"}
  else
    [[ -n "$release" ]] || release=$(_wt_pick_release "$version") || return 1
    bash "$_WT_KIT/new-base.sh" "$version" "$release"
  fi
}

# Pick a release branch of origin (live list), pre-filtered on the version.
_wt_pick_release() {
  local release
  echo "🔄 Listing release branches on origin..." >&2
  release=$(git -C "$_WT_MAIN" ls-remote --heads origin 'refs/heads/release/*' \
    | sed 's#.*refs/heads/##' | sort -rV \
    | default_fzf --prompt="Release branch > " --query="$1")
  [[ -n "$release" ]] || { echo "❌ No release branch selected." >&2; return 1; }
  echo "$release"
}

# ---------------------------------------------------------------------------------------------
# wt_rm [name...]
#   Removes worktrees (picked in fzf when no name is given). The branch is always kept.
#   Refuses a base still used by tickets. Uncommitted changes are stashed under the branch
#   name when you agree, otherwise the worktree is kept.
wt_rm() {
  _wt_paths || return 1
  local names=("$@") rows name confirm

  rows=$(_wt_rows)
  if [[ ${#names[@]} -eq 0 ]]; then
    mapfile -t names < <(_wt_table <<<"$rows" \
      | default_fzf --multi --prompt="Remove worktree(s) (TAB to select) > " | awk '{print $1}')
    [[ ${#names[@]} -gt 0 ]] || { echo "❌ Nothing selected."; return 1; }
  fi

  echo "Worktrees to remove (their branches are kept):"
  printf '  %s\n' "${names[@]}"
  [[ -n "$_wt_discard" ]] && echo "⚠️  Their uncommitted changes are discarded (stale: merged or remote gone)."
  read -rp "Remove them? [y/N] " confirm
  [[ "$confirm" == [yY] ]] || { echo "❌ Cancelled."; return 1; }

  for name in "${names[@]}"; do
    _wt_remove_one "$name" "$rows"
  done
  git -C "$_WT_MAIN" worktree prune
  echo
  echo "If the VM served one of them, switch it away: cd / && sudo vswitch <other>"
}

_wt_remove_one() {
  local name="$1" rows="$2" dir="$_WT_ROOT/$1" kind branch users unpushed link force=()

  if [[ -z "$name" || "$name" == */* || ! -f "$dir/.git" ]]; then
    echo "❌ $name: not a worktree of $_WT_ROOT."
    return 1
  fi
  kind=$(awk -F'\t' -v n="$name" '$1 == n { print $2 }' <<<"$rows")
  branch=$(awk -F'\t' -v n="$name" '$1 == n { print $3 }' <<<"$rows")

  if [[ "$kind" == base ]]; then
    users=$(awk -F'\t' -v n="$name" '$2 == "ticket" && $4 == n { printf "%s ", $1 }' <<<"$rows")
    if [[ -n "$users" ]]; then
      echo "❌ $name: base still used by $users— remove those first."
      return 1
    fi
  fi

  if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
    if [[ -n "$_wt_discard" ]]; then
      echo "🧹 $name: discarding uncommitted changes."
      force=(--force)
    else
      _wt_stash_changes "$name" "$branch" || return 1
    fi
  fi

  if [[ "$branch" != "(detached"* ]]; then
    unpushed=$(git -C "$_WT_MAIN" rev-list --count "refs/heads/$branch" --not --remotes=origin 2>/dev/null)
    [[ "${unpushed:-0}" -gt 0 ]] && echo "⚠️  $name: $unpushed commit(s) never pushed — still in the kept branch $branch."
  fi

  # Leave the terminal out of the folder being deleted.
  [[ "$PWD/" == "$dir/"* ]] && cd "$_WT_MAIN"

  # node_modules is a junction to the base's: drop the link itself first, so nothing can ever
  # delete the base's real node_modules through it.
  link="$dir/web/js/node_modules"
  if [[ -L "$link" ]]; then
    MSYS_NO_PATHCONV=1 cmd /c rmdir "$(cygpath -w "$link")" \
      || { echo "❌ $name: could not remove the node_modules link, not removed."; return 1; }
  fi

  echo "🗑️  Removing $name..."
  if git -C "$_WT_MAIN" worktree remove "${force[@]}" "$dir"; then
    echo "✅ $name removed${branch:+ (branch $branch kept)}."
  else
    echo "❌ $name: git worktree remove failed (a file open in nvim, Explorer or the VM?)."
    return 1
  fi
}

# Offers to stash a worktree's uncommitted changes (untracked files included) under the branch
# name. The stash list is shared by all worktrees, so the stash outlives the removed folder:
# restore it later from any worktree with git stash list / git stash pop stash@{n}.
_wt_stash_changes() {
  local name="$1" branch="$2" message answer
  [[ "$branch" == "(detached"* || -z "$branch" ]] && message="$name" || message="$branch"

  echo "⚠️  $name: uncommitted changes:"
  git -C "$_WT_ROOT/$name" status --short | head -n 10 | sed 's/^/     /'
  read -rp "Stash them as '$message' and remove $name? [y/N] " answer
  if [[ "$answer" != [yY] ]]; then
    echo "❌ $name: not removed. Commit or stash the changes first."
    return 1
  fi

  if git -C "$_WT_ROOT/$name" stash push --include-untracked -m "$message"; then
    echo "📦 $name: changes stashed as '$message' (git stash list)."
  else
    echo "❌ $name: git stash failed, not removed."
    return 1
  fi
}

# ---------------------------------------------------------------------------------------------
# wt_stale: worktrees (bases excluded) no longer needed — branch merged by a Bitbucket
# "Merged in <branch>" commit into an origin release branch or master with no commit since, or
# remote branch deleted. A new branch with no commit of its own is never listed.
wt_stale() {
  _wt_paths || return 1
  local rows
  echo "🔄 Fetching origin..."
  spinner git -C "$_WT_MAIN" fetch -p -q || echo "⚠️  git fetch failed: using the local origin/* copies."
  rows=$(_wt_stale_rows)
  if [[ -z "$rows" ]]; then
    echo "✅ No stale worktree."
    return 0
  fi
  { printf 'WORKTREE\tBRANCH\tREASON\n'; echo "$rows"; } | _wt_table
}

_wt_stale_rows() {
  local rows branches merged gone name kind branch base reason
  local targets=(--remotes='origin/release/*' --remotes=origin/master)

  rows=$(_wt_rows | awk -F'\t' '$2 != "base" && $3 !~ /^\(detached/')
  [[ -n "$rows" ]] || return 0
  branches=$(cut -f3 <<<"$rows")

  # Bulk queries, filtered by grep: each git call costs ~0.5 s on Windows, and a bash read loop
  # over thousands of lines takes seconds. Branches with a Bitbucket "Merged in <branch> (…"
  # commit in a release branch or master, and branches whose remote is gone.
  # Merged, and no commit added since: also needs the tip inside a release branch or master
  # (for-each-ref --merged, repeated, is an OR).
  merged=$(git -C "$_WT_MAIN" log --merges --format=%s "${targets[@]}" \
    | sed -n 's/^Merged in \([^ ]*\) (.*/\1/p' | grep -Fx -f <(echo "$branches") \
    | grep -Fx -f <(git -C "$_WT_MAIN" for-each-ref --format='%(refname:short)' \
        $(git -C "$_WT_MAIN" for-each-ref --format='--merged=%(refname)' \
          refs/remotes/origin/release refs/remotes/origin/master) refs/heads) | sort -u)
  gone=$(git -C "$_WT_MAIN" for-each-ref --format='%(refname:short)%09%(upstream:track)' refs/heads \
    | awk -F'\t' '$2 == "[gone]" { print $1 }' | grep -Fx -f <(echo "$branches"))

  while IFS=$'\t' read -r name kind branch base; do
    reason=""
    if [[ $'\n'"$merged"$'\n' == *$'\n'"$branch"$'\n'* ]]; then
      reason="merged"
    elif [[ $'\n'"$gone"$'\n' == *$'\n'"$branch"$'\n'* ]]; then
      reason="remote branch deleted"
    fi
    [[ -n "$reason" ]] || continue
    [[ -n "$(git -C "$_WT_ROOT/$name" status --porcelain 2>/dev/null)" ]] && reason+=" ⚠️ local changes"
    printf '%s\t%s\t%s\n' "$name" "$branch" "$reason"
  done <<<"$rows"
}

# wt_clean: list the stale worktrees, pick some in fzf (TAB), remove them with wt_rm.
# Stale means merged or remote gone, so their uncommitted changes are discarded, not stashed
# (_wt_discard is seen by wt_rm and _wt_remove_one through bash's dynamic scoping).
wt_clean() {
  _wt_paths || return 1
  local rows names _wt_discard=1
  echo "🔄 Fetching origin..."
  spinner git -C "$_WT_MAIN" fetch -p -q || echo "⚠️  git fetch failed: using the local origin/* copies."
  rows=$(_wt_stale_rows)
  [[ -n "$rows" ]] || { echo "✅ No stale worktree."; return 0; }
  mapfile -t names < <(_wt_table <<<"$rows" \
    | default_fzf --multi --prompt="Stale worktrees to remove (TAB to select) > " | awk '{print $1}')
  [[ ${#names[@]} -gt 0 ]] || { echo "❌ Nothing selected."; return 1; }
  wt_rm "${names[@]}"
}
