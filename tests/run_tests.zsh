#!/usr/bin/env zsh

# gwx prune regression tests.
# Run with: zsh tests/run_tests.zsh
# Builds throwaway repos under a mktemp dir; nothing outside it is touched.

set -u

PLUGIN="${0:A:h:h}/gwx.plugin.zsh"
source "$PLUGIN"

pass=0
fail=0
rc=0
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ((pass+=1))
    print -r -- "ok   - $name"
  else
    ((fail+=1))
    print -r -- "FAIL - $name"
  fi
}

exists()      { [[ -e "$1" ]]; }
not_exists()  { [[ ! -e "$1" ]]; }
branch_exists() { git -C "$1" show-ref --verify --quiet "refs/heads/$2"; }
branch_gone()   { ! git -C "$1" show-ref --verify --quiet "refs/heads/$2"; }
has_text()    { grep -q -- "$1" "$2"; }

new_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  printf 'base\n' > "$repo/base.txt"
  git -C "$repo" add base.txt
  git -C "$repo" commit -qm base
}

# A bare remote used to give branches a real upstream (origin/...).
new_remote() {
  git init -q --bare "$tmp_root/${1:t}-remote.git"
}

# A worktree whose branch is merged into main and is left clean.
add_merged_worktree() {
  local repo="$1" branch="$2"
  local name="${repo:t}"
  local wt="$tmp_root/$name-wt-$branch"
  mkdir -p "$tmp_root/$(dirname "$name-wt-$branch")"
  git -C "$repo" worktree add -q -b "$branch" "$wt"
  printf '%s work\n' "$branch" >> "$wt/base.txt"
  git -C "$wt" add base.txt
  git -C "$wt" commit -qm "$branch work"
  git -C "$repo" merge -q --no-ff "$branch" -m "merge $branch"
}

# The incident scenario: a branch NOT merged into main, but with an upstream
# (origin/...) at the same tip. git branch -d would consider it safe to delete.
add_unmerged_upstream_worktree() {
  local repo="$1" branch="$2"
  local name="${repo:t}"
  local wt="$tmp_root/$name-wt-$branch"
  mkdir -p "$tmp_root/$(dirname "$name-wt-$branch")"
  git -C "$repo" worktree add -q -b "$branch" "$wt"
  printf '%s work\n' "$branch" >> "$wt/base.txt"
  git -C "$wt" add base.txt
  git -C "$wt" commit -qm "$branch work"
  git -C "$repo" remote add origin "$tmp_root/$name-remote.git"
  git -C "$repo" push -q -u origin "$branch"
}

run_prune() {
  local repo="$1" out="$2"; shift 2
  ( cd "$repo" && gwx prune --force "$@" ) >"$out" 2>&1
  rc=$?
}

# 1. Merged, clean worktree -> removed, branch deleted.
repo="$tmp_root/t1"
new_repo "$repo"
add_merged_worktree "$repo" feat/t1
out="$tmp_root/t1.out"
run_prune "$repo" "$out"
check "t1: merged worktree removed"        not_exists "$tmp_root/t1-wt-feat/t1"
check "t1: merged branch deleted"          branch_gone "$repo" feat/t1
check "t1: success exit code"              test "$rc" -eq 0

# 2. Incident regression: unmerged branch with upstream at same tip -> untouched.
repo="$tmp_root/t2"
new_remote "$repo"
new_repo "$repo"
add_unmerged_upstream_worktree "$repo" docs/solution-doc
out="$tmp_root/t2.out"
run_prune "$repo" "$out"
check "t2: incident branch still exists"   branch_exists "$repo" docs/solution-doc
check "t2: incident worktree still exists" exists "$tmp_root/t2-wt-docs/solution-doc"
check "t2: nothing selected"               has_text "no worktrees merged" "$out"

# 3. Remote refs are rejected as prune targets.
repo="$tmp_root/t3"
new_remote "$repo"
new_repo "$repo"
add_unmerged_upstream_worktree "$repo" docs/solution-doc
out="$tmp_root/t3.out"
run_prune "$repo" "$out" origin/docs/solution-doc
check "t3: remote target rejected"         test "$rc" -eq 1
check "t3: rejection message"              has_text "not a local branch" "$out"

# 4. Dirty worktree -> skipped with a reason and hint; --force-remove works.
repo="$tmp_root/t4"
new_repo "$repo"
add_merged_worktree "$repo" feat/t4
printf 'dirty\n' >> "$tmp_root/t4-wt-feat/t4/base.txt"
printf 'untracked\n' > "$tmp_root/t4-wt-feat/t4/untracked.txt"
out="$tmp_root/t4.out"
run_prune "$repo" "$out"
check "t4: dirty worktree not removed"     exists "$tmp_root/t4-wt-feat/t4"
check "t4: failure exit code"              test "$rc" -eq 1
check "t4: git reason shown"               has_text "modified or untracked" "$out"
check "t4: force-remove hint shown"        has_text "force-remove" "$out"
out="$tmp_root/t4b.out"
run_prune "$repo" "$out" --force-remove
check "t4: force-remove removed worktree"  not_exists "$tmp_root/t4-wt-feat/t4"
check "t4: force-remove pruned branch"     branch_gone "$repo" feat/t4
check "t4: force-remove success exit"      test "$rc" -eq 0

# 5. Detached worktree is skipped, not misattributed to the previous branch.
repo="$tmp_root/t5"
new_repo "$repo"
add_merged_worktree "$repo" feat/t5
git -C "$repo" worktree add -q --detach "$tmp_root/t5-wt-detach" main
out="$tmp_root/t5.out"
run_prune "$repo" "$out"
check "t5: merged worktree removed"        not_exists "$tmp_root/t5-wt-feat/t5"
check "t5: detached worktree kept"         exists "$tmp_root/t5-wt-detach"
check "t5: detached skipped notice"        has_text "detached HEAD" "$out"
check "t5: merged branch deleted"          branch_gone "$repo" feat/t5

# 6. The worktree you are standing in is never removed.
repo="$tmp_root/t6"
new_repo "$repo"
add_merged_worktree "$repo" feat/t6
out="$tmp_root/t6.out"
( cd "$tmp_root/t6-wt-feat/t6" && gwx prune --force ) >"$out" 2>&1
rc=$?
check "t6: current worktree kept"          exists "$tmp_root/t6-wt-feat/t6"
check "t6: current skipped notice"         has_text "current worktree" "$out"
check "t6: success exit code"              test "$rc" -eq 0

# 7. --keep-branch: worktree removed, branch kept.
repo="$tmp_root/t7"
new_repo "$repo"
add_merged_worktree "$repo" feat/t7
out="$tmp_root/t7.out"
run_prune "$repo" "$out" --keep-branch
check "t7: worktree removed"               not_exists "$tmp_root/t7-wt-feat/t7"
check "t7: branch kept"                    branch_exists "$repo" feat/t7

print -r -- ""
print -r -- "passed: $pass, failed: $fail"
[[ "$fail" -eq 0 ]]