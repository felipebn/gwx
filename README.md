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
gwx prune develop              # remove worktrees merged into develop
```

### update (`-u`)

Pull the latest version of gwx and reload the plugin without restarting your shell.

```bash
gwx update
gwx -u
```

## License

MIT
