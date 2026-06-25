# gwx — Git Worktree Extension

A zsh plugin to switch between and prune git worktrees.

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

### prune (`-p`)

Remove worktrees whose branches are fully merged into `main` (or a specified branch). Also deletes the branch ref by default.

```bash
gwx prune                      # remove worktrees merged into main
gwx -p --force                 # skip confirmation
gwx prune --keep-branch        # keep the git branch after removing worktree
gwx prune develop              # remove worktrees merged into develop
```

## License

MIT
