# gwx — Git Worktree Extension

A zsh plugin to switch between, create, and prune git worktrees.

## Install

### Oh My Zsh

```bash
git clone https://github.com/felipebn/gwx.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/gwx
```

Then add `gwx` to your plugins in `~/.zshrc`:

```zsh
plugins=(git gwx)
```

### Manual

```bash
git clone https://github.com/felipebn/gwx.git ~/gwx
echo 'source ~/gwx/gwx.plugin.zsh' >> ~/.zshrc
```

### One-liner (Oh My Zsh only)

```bash
git clone https://github.com/felipebn/gwx.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/gwx \
  && sed -i 's/^plugins=(/plugins=(gwx /' ~/.zshrc
```

### Optional: fzf

Install [fzf](https://github.com/junegunn/fzf) for fuzzy search when switching worktrees. Without it, `gwx switch` falls back to a numbered menu.

```bash
# Ubuntu/Debian
sudo apt install fzf

# macOS
brew install fzf
```

## Usage

```
gwx [command] [options]
```

### switch (`-s`)

Interactively pick a worktree and `cd` into it.

```bash
gwx           # same as gwx switch
gwx switch
gwx -s
```

### create (`-c`)

Create a worktree for a branch and `cd` into it. If the branch does not exist, it is created from the current HEAD (or the branch given with `--branch`).

The worktree is created in the sibling directory `<repo-parent>/<branch-name>`. Use `--name` to override the directory name and `--worktree-parent` to choose a different parent.

```bash
gwx create feat/foo               # checkout or create branch feat/foo, worktree in ../feat/foo
gwx create fix/x --branch main    # create branch fix/x from main
gwx create feat/foo --name hotfix # worktree in ../hotfix, branch feat/foo
gwx create feat/foo --worktree-parent ~/worktrees
```

### prune (`-p`)

Remove worktrees whose branches are fully merged into `main` (or a specified branch). Also deletes the branch ref by default.

```bash
gwx prune                      # remove worktrees merged into main
gwx -p --force                 # skip confirmation
gwx prune --keep-branch        # keep the git branch after removing worktree
gwx prune --force-remove       # discard uncommitted/untracked files in selected worktrees
gwx prune develop              # remove worktrees merged into develop
```

**Options**

- `-f, --force`: skip the confirmation prompt.
- `-k, --keep-branch`: keep the local branch after removing the worktree.
- `--force-remove`: pass `--force` to `git worktree remove`, discarding uncommitted or untracked files in the selected worktrees. Branch deletion is never affected by this flag.

**Safety**

- The worktree you are currently in is never removed.
- A branch is only deleted if it is strictly merged into the target branch — it is *not* deleted merely because it matches its remote-tracking upstream.
- Every skipped worktree (detached HEAD, current, dirty, locked) and every kept branch is reported with a reason and a recovery hint.
- `prune` only accepts a local branch as the target (e.g. `gwx prune origin/main` is rejected).

### update (`-u`)

Pull the latest version of gwx and reload the plugin without restarting your shell.

```bash
gwx update
gwx -u
```

## License

MIT
