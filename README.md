# bash-tools-utils
small bash scripts to help my workflow day to day

# requirements
- bash (...)
- fzf (...)
- jq (https://jqlang.org/download/)
- git (used only for git helpers)


# Window terminal
- For faster start time : 

    `"C:/Program Files/Git/bin/bash.exe" --noprofile -i`

- For faster ssh rendering : 
    Use the powershell ssh implementation. Rendering is much faster

    `alias ssh='/c/Windows/System32/OpenSSH/ssh.exe'`


# ZSH user : 
Make the default sheel bash. Because zsh is not compatible with bash
```zsh
# Source - https://stackoverflow.com/a
# Posted by larsks
# Retrieved 2026-01-23, License - CC BY-SA 3.0
exec bash
```

# Command / How to use

# Project Navigation Utilities

Utilities for managing and navigating frequently used projects.

Projects are stored in:

```text
~/bash_projects.json
```

Example:

```json
{
  "viridem": "/var/www/viridem",
  "website": "/var/www/website",
  "api": "/home/user/projects/api"
}
```

---

## op

Interactive project selector.

### Usage

```bash
op
```

### Features

* Displays all registered projects through `fzf`.
* Changes the current shell directory to the selected project.

### Example

```bash
op
```

Select:

```text
viridem
```

Result:

```bash
cd /var/www/viridem
```

---

## opv

Open a project and launch Neovim.

### Usage

```bash
opv
```

### Workflow

1. Select a project.
2. Change to the project directory.
3. Launch:

```bash
nvim .
```

---

## add_project

Register a project.

### Usage

```bash
add_project <name>
add_project <name> <path>
```

### Examples

Add the current directory:

```bash
add_project viridem
```

Add a specific directory:

```bash
add_project api /home/user/projects/api
```

Result:

```text
✓ Project 'api' → /home/user/projects/api
```

### Notes

* Automatically creates `~/bash_projects.json` if missing.
* Paths are normalized to absolute paths.
* Requires `jq`.

---

## remove_project

Remove a registered project.

### Usage

```bash
remove_project <name>
```

### Example

```bash
remove_project api
```

Result:

```text
🗑️ Removed project 'api'
```

### Notes

* Requires `jq`.
* Automatically refreshes the in-memory project list.

---

## opr

Interactive project removal.

### Usage

```bash
opr
```

### Workflow

1. Select a project from `fzf`.
2. Confirm deletion.
3. Remove the project entry from `~/bash_projects.json`.

Example:

```text
Delete project 'api'?
[y/N]
```

---

## list_projects

Display all registered projects.

### Usage

```bash
list_projects
```

### Example Output

```text
viridem -> /var/www/viridem
website -> /var/www/website
api -> /home/user/projects/api
```

---

## refresh_projects

Reload projects from disk.

### Usage

```bash
refresh_projects
```

### Example Output

```text
🔄 Reloading projects...
✅ Projects reloaded (12 entries)
```

Useful after manually editing:

```text
~/bash_projects.json
```

---

## go_to_project

Navigate directly to a project by name.

### Usage

```bash
go_to_project <name>
```

### Example

```bash
go_to_project viridem
```

Result:

```bash
cd /var/www/viridem
```

---

## Requirements

### jq

Used for adding and removing projects.

Ubuntu/Debian:

```bash
sudo apt install jq
```

Fedora:

```bash
sudo dnf install jq
```

macOS:

```bash
brew install jq
```

### fzf

Used for interactive project selection.

Ubuntu/Debian:

```bash
sudo apt install fzf
```

macOS:

```bash
brew install fzf
```

---

## Quick Start

Add your current project:

```bash
add_project viridem
```

Jump to a project:

```bash
op
```

Open a project in Neovim:

```bash
opv
```

Remove a project:

```bash
opr
```

## Git Utilities

A collection of Git helper functions for branch creation, checkout, pulling, stash management, and repository cleanup.


### create_branch_from_ticket

Create a Git branch from a Jira ticket number or Jira URL.

#### Usage

```bash
create_branch_from_ticket <ticket-number>
create_branch_from_ticket <jira-url>

create_branch_from_ticket -p <prefix> <ticket-number>
create_branch_from_ticket --prefix <prefix> <ticket-number>

create_branch_from_ticket -n <branch-name>
create_branch_from_ticket --name <branch-name>
```

#### Examples

Create a branch from ticket `12345` using the default prefix (`BSP`):

```bash
create_branch_from_ticket 12345
```

Result:

```text
feature/BSP-12345
```

Create a branch using a custom prefix:

```bash
create_branch_from_ticket -p ABC 12345
```

Result:

```text
feature/ABC-12345
```

Create a branch from a Jira URL:

```bash
create_branch_from_ticket https://jira.company.com/browse/BSP-12345
```

Create a branch without any ticket prefix:

```bash
create_branch_from_ticket -n my-custom-branch
```

#### Workflow

1. Fetches remote branches.
2. Detects existing branches containing the ticket number.
3. Allows:

   * Switching to an existing branch.
   * Creating a new branch.
4. Prompts for a base branch.

   * Prefers `release/*` and `hotfix/*` branches.
5. Prompts for branch type:

   * `feature`
   * `bugfix`
6. Optionally adds a suffix.
7. Creates and checks out the branch.
8. Offers to restore any stashed changes.

#### Generated Branch Format

```text
feature/BSP-12345
feature/BSP-12345-v1
bugfix/BSP-12345-fix-validation
```

---
## git_checkout

Interactive branch checkout.

### Usage

```bash
git_checkout
```

### Features

* Fetches local and remote branches.
* Displays all available branches through `fzf`.
* Checks out the selected branch.

### Alias

```bash
gc
```

---

## apply_stash

Interactive stash restoration helper.

### Usage

```bash
apply_stash
```

### Options

Allows you to:

* Show stash summary
* Show detailed patch
* Apply stash
* Skip stash restoration

### Typical Flow

```text
Show stash?
 ├─ yes
 │   ├─ Show details?
 │   └─ Apply stash?
 ├─ apply
 └─ skip
```

---

## git_stash_show

Shortcut for opening the stash recovery workflow.

### Usage

```bash
git_stash_show
```

---

## gclean

Delete local branches whose remote counterparts no longer exist.

### Usage

```bash
gclean
```

### Equivalent To

```bash
git fetch -p

git branch -vv \
| grep ': gone]' \
| awk '{print $1}' \
| xargs git branch -D
```

### Example

Before:

```text
feature/BSP-1001
feature/BSP-1002
feature/BSP-1003
```

After remote cleanup:

```bash
gclean
```

Deleted:

```text
feature/BSP-1002
feature/BSP-1003
```

---

For a README, I'd keep this one short since it's a single-purpose utility.

---

# Bitbucket Utilities

Helpers for creating Bitbucket pull requests directly from the command line.

---

## pr

Alias for `pra`.

### Usage

```bash
pr
```

---

## pra

Create a Bitbucket Pull Request URL for the current branch.

### Usage

```bash
pra
```

### Workflow

1. Prompts for the destination branch.
2. Detects:

   * Current Git repository
   * Repository owner/workspace
   * Repository name
   * Current branch
3. Builds a Bitbucket Pull Request URL.
4. Opens the URL in your browser.

### Example

Current branch:

```text
feature/BSP-12345-fix-validation
```

Selected destination branch:

```text
release/2026.06
```

Generated URL:

```text
https://bitbucket.org/company/my-repo/pull-requests/new?source=feature/BSP-12345-fix-validation&dest=release/2026.06
```

The browser opens directly on Bitbucket's **Create Pull Request** page with the source and destination branches already populated.

---

## Requirements

### Git Remote

The repository must have an `origin` remote configured:

```bash
git remote -v
```

Example:

```text
origin  git@bitbucket.org:company/my-repo.git
```

or

```text
origin  https://bitbucket.org/company/my-repo.git
```

### Base Branch Selector

This command relies on:

```bash
git_select_base_branch
```

to choose the target branch for the pull request.

---

## Typical Workflow

```bash
# Create a feature branch
create_branch_from_ticket 12345

# Work on your changes
git add .
git commit

# Push branch
git push -u origin HEAD

# Create pull request
pr
```

### Benefits

* No need to manually navigate to Bitbucket.
* Automatically detects the current branch.
* Reduces mistakes when selecting source/destination branches.
* Integrates with the branch-selection workflow already used by other Git utilities.


---

## Viridem Worktrees

`bash_utils/worktree.sh` manages the Viridem git worktrees without Claude. Creating a worktree or
a base goes through the scripts of the viridem-worktree kit (`~/.claude/skills/viridem-worktree`),
so the logic stays in one place; the paths come from the kit's `.env` (`VIRIDEM_MAIN`,
`VIRIDEM_WORKTREES`).

Requires the viridem-worktree kit installed (`install-pc.sh`), fzf, and for `wt_add` the
`worktree-nvim-tab` skill (`~/.claude/skills/worktree-nvim-tab/open-tab.sh`).

| Command | What it does |
| --- | --- |
| `wt_add [14199\|BSP-14199\|Jira URL] [version] [bugfix\|feature]` | Creates the ticket worktree (`new-worktree.sh`), then opens a Git Bash tab with Neovim + Claude Code on it. A missing version or type is picked in fzf. When a branch of the ticket (`bugfix/` or `feature/`, local or on origin) or its folder already exists, it lists them and asks for a suffix: `BSP-14199-v2`. |
| `wt_base [version] [release-branch]` | Existing base: updates it to the latest of its release branch, or moves it to another one (`update-base.sh`). New base: pick the `origin/release/*` branch in fzf (`new-base.sh`). |
| `wt_rm [name...]` | Removes worktrees, picked in fzf (TAB for several). The branch is always kept. |
| `wt_stale` | Lists the worktrees no longer needed: branch merged into an origin release branch or `master` (Bitbucket "Merged in <branch>" commit, no commit since), or remote branch deleted. |
| `wt_clean` | `wt_stale`, then pick in fzf and remove with `wt_rm`. |
| `ow` / `owv` | Go to a worktree / open it in Neovim (`project.sh`). |

### Safety in `wt_rm`

* A base still used by ticket worktrees is never removed.
* A worktree with uncommitted changes asks first: answer `y` to stash them (untracked files
  included) with the branch name as message, then remove it; anything else keeps it. The stash
  is shared by all worktrees: find it with `git stash list`.
* `wt_clean` only offers stale worktrees (merged or remote gone), so it discards their
  uncommitted changes without stashing; the confirmation prompt says so.
* Commits never pushed are reported; they stay in the kept branch.
* The `web/js/node_modules` junction to the base is removed first, so the base's real
  `node_modules` can never be deleted through it.
* After removal, switch the VM away if it served that worktree: `cd / && sudo vswitch <other>`.

### Example

```bash
wt_add 14199            # pick the base and bugfix/feature in fzf
wt_base v2026.5         # update the v2026.5 base
wt_stale                # what can go?
wt_clean                # pick and remove
```

# Todos 
- [x] Add spinner program 
- [ ] add spinner for thing taht take time. like fetching
- [x] Add protection 
    - [x] Git (if not installed.)
    - [x] ... jq
