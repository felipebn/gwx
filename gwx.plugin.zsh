_gwx_usage() {
  cat <<'EOF' >&2
Usage: gwx <command> [options]

Commands:
  switch, -s    Interactively switch between worktrees
  create, -c    Create a worktree for a branch and cd into it
  prune,  -p    Remove worktrees whose branches are fully merged into main

Create options:
  -b, --branch <name>          Base for a NEW branch (default: current HEAD)
  --name <name>                Override the worktree directory name (default: branch name)
  --worktree-parent <dir>      Parent directory for the worktree (default: sibling of repo root)

Prune options:
  -f, --force          Skip confirmation prompt
  -k, --keep-branch    Keep the local branch after removing the worktree

Examples:
  gwx switch
  gwx -s
  gwx create feat/foo
  gwx create fix/x --branch main
  gwx create feat/foo --name hotfix --worktree-parent ~/worktrees
  gwx prune
  gwx -p --force
  gwx prune --keep-branch
  gwx prune develop   # use a different target branch than main
EOF
}

_gwx_switch() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwx: not in a git repository" >&2
    return 1
  fi

  local current
  current=$(git worktree list --porcelain | awk '/^worktree/{p=$2} /^HEAD/{print p; exit}')

  local worktrees
  worktrees=$(git worktree list --porcelain | awk '
    /^worktree/ {p=$2}
    /^branch/   {b=$2; sub("refs/heads/","",b); print p "\t" b}
  ')

  if [[ -z "$worktrees" ]]; then
    echo "gwx: no worktrees found" >&2
    return 1
  fi

  if command -v fzf &>/dev/null; then
    local selected
    selected=$(echo "$worktrees" | fzf \
      --ansi \
      --delimiter='\t' \
      --with-nth=2 \
      --bind='ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' \
      --preview='echo "Path: {1}"' \
      --preview-window='bottom:1' \
      --height='~40%' \
      --header='ctrl-d/u: scroll preview  |  enter: switch')
    if [[ -n "$selected" ]]; then
      cd "$(echo "$selected" | cut -f1)" || return
    fi
  else
    local -a paths branches
    while IFS=$'\t' read -r wt_path branch; do
      paths+=("$wt_path")
      if [[ "$wt_path" == "$current" ]]; then
        branches+=("$branch (current)")
      else
        branches+=("$branch")
      fi
    done <<< "$worktrees"

    echo "Select worktree:"
    select branch in "${branches[@]}"; do
      if [[ -n "$branch" ]]; then
        cd "${paths[$REPLY]}" || return
        break
      else
        echo "Invalid selection" >&2
      fi
    done
  fi
}

_gwx_create() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwx: not in a git repository" >&2
    return 1
  fi

  local branch_name start_point name worktree_parent

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch|-b) start_point="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --worktree-parent) worktree_parent="$2"; shift 2 ;;
      -*) echo "gwx: unknown create option: $1" >&2; _gwx_usage; return 1 ;;
      *) [[ -n "$branch_name" ]] && { echo "gwx: too many arguments" >&2; _gwx_usage; return 1; }
         branch_name="$1"; shift ;;
    esac
  done

  if [[ -z "$branch_name" ]]; then
    echo "gwx: create requires a branch name" >&2
    _gwx_usage
    return 1
  fi

  local repo_root dir_name wt_path
  repo_root=$(git rev-parse --show-toplevel)
  [[ -z "$worktree_parent" ]] && worktree_parent=$(dirname "$repo_root")
  dir_name=${name:-$branch_name}
  wt_path="$worktree_parent/$dir_name"

  if [[ -e "$wt_path" ]]; then
    echo "gwx: path '$wt_path' already exists" >&2
    return 1
  fi

  local args
  if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    args=(add "$wt_path" "$branch_name")
  else
    args=(add -b "$branch_name" "$wt_path")
    [[ -n "$start_point" ]] && args+=("$start_point")
  fi

  if git worktree "${args[@]}"; then
    echo "Created worktree: $wt_path"
    cd "$wt_path" || return 1
  else
    return 1
  fi
}

_gwx_prune() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwx: not in a git repository" >&2
    return 1
  fi

  local force=false keep_branch=false target_branch="main"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f) force=true; shift ;;
      --keep-branch|-k) keep_branch=true; shift ;;
      -*) echo "gwx: unknown prune option: $1" >&2; _gwx_usage; return 1 ;;
      *) target_branch="$1"; shift ;;
    esac
  done

  if ! git rev-parse --verify "$target_branch" >/dev/null 2>&1; then
    echo "gwx: target branch '$target_branch' not found" >&2
    return 1
  fi

  local -a to_prune_paths to_prune_branches
  while IFS=$'\t' read -r wt_path branch; do
    if [[ "$branch" == "$target_branch" ]]; then
      continue
    fi
    if git merge-base --is-ancestor "$branch" "$target_branch" 2>/dev/null; then
      to_prune_paths+=("$wt_path")
      to_prune_branches+=("$branch")
    fi
  done < <(git worktree list --porcelain | awk '
    /^worktree/ {p=$2}
    /^branch/   {b=$2; sub("refs/heads/","",b); print p "\t" b}
  ')

  if [[ ${#to_prune_paths[@]} -eq 0 ]]; then
    echo "gwx: no worktrees merged into '$target_branch'"
    return 0
  fi

  echo "Worktrees merged into '$target_branch':"
  local i
  for ((i=1; i<=${#to_prune_paths[@]}; i++)); do
    printf "  %s  (%s)\n" "${to_prune_paths[$i]}" "${to_prune_branches[$i]}"
  done

  if ! $force; then
    echo -n "Remove these worktrees? [y/N] "
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "yes" ]] && return 0
  fi

  local errors=0
  for ((i=1; i<=${#to_prune_paths[@]}; i++)); do
    if git worktree remove "${to_prune_paths[$i]}" 2>/dev/null; then
      echo "Removed worktree: ${to_prune_paths[$i]}"
      if ! $keep_branch; then
        if git branch -d "${to_prune_branches[$i]}" 2>/dev/null; then
          echo "  -> pruned branch: ${to_prune_branches[$i]}"
        fi
      fi
    else
      echo "gwx: failed to remove ${to_prune_paths[$i]}" >&2
      ((errors++))
    fi
  done

  return $errors
}

gwx() {
  if [[ $# -eq 0 ]]; then
    _gwx_switch
    return
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    switch|-s)          _gwx_switch "$@" ;;
    create|-c)          _gwx_create "$@" ;;
    prune|-p)           _gwx_prune "$@" ;;
    -h|--help|help)     _gwx_usage ;;
    *)                  echo "gwx: unknown command '$cmd'" >&2; _gwx_usage; return 1 ;;
  esac
}
