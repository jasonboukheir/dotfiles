#!/usr/bin/env bash
# cws - Claude Code multi-repo workspace manager using Sapling worktrees

sl_wt="sl --config worktree.enabled=true worktree"

if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
  echo "cws - Claude Code multi-repo workspace manager"
  echo ""
  echo "Usage:"
  echo "  cws <name> [repos...]  Create a workspace and launch Claude"
  echo "  cws rm <name>          Remove a workspace and its worktrees"
  echo "  cws ls                 List existing workspaces"
  echo "  cws help               Show this help"
  echo ""
  echo "fbsource is always the primary workspace. Additional repos"
  echo "(default: configerator) are added via --add-dir."
  echo "Workspaces are created in ~/workspaces/<name>."
  exit 0
fi

if [[ "$1" == "ls" ]]; then
  if [[ ! -d "$HOME/workspaces" ]] || [[ -z "$(ls -A "$HOME/workspaces" 2>/dev/null)" ]]; then
    echo "No workspaces found."
    exit 0
  fi
  for ws in "$HOME/workspaces"/*/; do
    name="$(basename "$ws")"
    repos=""
    for dir in "$ws"*/; do
      [[ -d "$dir" ]] && repos="$repos $(basename "$dir")"
    done
    echo "$name:$repos"
  done
  exit 0
fi

if [[ "$1" == "rm" ]]; then
  name="$2"
  if [[ -z "$name" ]]; then
    echo "Usage: cws rm <name>"
    exit 1
  fi
  base="$HOME/workspaces/$name"
  for dir in "$base"/*/; do
    repo_name="$(basename "$dir")"
    src="/data/users/$USER/$repo_name"
    [[ -d "$dir" ]] && (cd "$src" && $sl_wt remove -y "$dir" --reason "clean up workspace worktree | sl help worktree")
  done
  rm -rf "$base"
  exit 0
fi

name="$1"
shift
base="$HOME/workspaces/$name"

extra_repos=("$@")

_cws_add_dirs() {
  local add_dirs=()
  for dir in "$base"/*/; do
    [[ -d "$dir" ]] || continue
    local repo_name="$(basename "$dir")"
    [[ "$repo_name" != "fbsource" ]] && add_dirs+=(--add-dir "$dir")
  done
  echo "${add_dirs[@]}"
}

if [[ -d "$base/fbsource/.eden" ]]; then
  echo "Resuming workspace $name"
  (cd "$base/fbsource" && claude $(_cws_add_dirs))
  exit 0
fi

mkdir -p "$base"

all_repos=(fbsource "${extra_repos[@]}")
for repo in "${all_repos[@]}"; do
  src="/data/users/$USER/$repo"
  if [[ -d "$src" ]]; then
    echo "Creating $repo worktree..."
    (cd "$src" && $sl_wt add "$base/$repo" --reason "create workspace worktree | sl help worktree")
  else
    echo "Skipping $repo: $src not found"
  fi
done

echo "Workspace ready at $base"
(cd "$base/fbsource" && claude $(_cws_add_dirs))
