# dotfiles

Automated Debian 12 (Bookworm) environment setup. A single idempotent script that installs and configures a full terminal development environment from a fresh install.

---

## What Gets Installed

| Tool | Purpose |
|---|---|
| **zsh** + Oh My Zsh | Shell with autosuggestions, syntax highlighting, autocomplete |
| **Starship** | Cross-shell prompt |
| **Neovim** (latest) | Editor, configured with Kickstart.nvim |
| **tmux** + TPM | Terminal multiplexer with resurrect & sensible plugins |
| **fzf** | Fuzzy finder |
| **eza** | Modern `ls` replacement |
| **bat** | Modern `cat` replacement (`batcat` → `bat` symlink) |
| **fd** | Modern `find` replacement (`fdfind` → `fd` symlink) |
| **ripgrep** | Modern `grep` replacement |
| **delta** | Better `git diff` pager |
| **glow** | Markdown renderer for the terminal |
| **zoxide** | Smarter `cd` with frecency ranking |
| **Go** (latest) | Go toolchain from go.dev |
| **jq** | JSON processor |
| **pipx** / **python3-pip** | Python tooling |

### Shell Aliases Configured

```zsh
ls   → eza --icons=always
ll   → eza -lh --icons=always
la   → eza -lah --icons=always
cat  → bat --paging=never
grep → rg
find → fd
```

### PATH Additions

```
~/.local/bin          # eza, glow, delta, bat, fd symlinks
/opt/nvim-linux-x86_64/bin  # Neovim
/usr/local/go/bin     # Go toolchain
~/go/bin              # Go-compiled binaries (e.g. shogunhound)
```

---

## Usage

### Fresh Install

```bash
git clone git@github.com:nethoundsh/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Then apply the new shell:

```bash
exec zsh
```

Open Neovim once to let Kickstart initialize and download plugins:

```bash
nvim
```

### Dry Run

Preview every action without making any changes:

```bash
./install.sh --dry-run
```

### Help

```bash
./install.sh --help
```

---

## Idempotency

The script is safe to re-run. Every section checks whether a tool is already installed before doing anything. Re-running on an already-configured machine will skip everything that's already in place and only act on what's missing.

If a non-critical tool fails (e.g. a GitHub release URL is unreachable), the script logs a warning and continues rather than aborting. A summary of any failures is printed at the end:

```
======================================================================
  Setup complete!

  The following tools failed to install and were skipped:
    - eza

  Re-run or manually install the above tools.
======================================================================
```

---

## tmux Config

The included `.tmux.conf` sets the following:

| Binding | Action |
|---|---|
| `Ctrl+a` | Prefix (replaces default `Ctrl+b`) |
| `prefix + \|` | Split pane horizontally |
| `prefix + -` | Split pane vertically |
| `prefix + h/j/k/l` | Navigate panes (Vim-style) |
| `prefix + r` | Reload tmux config |
| `v` (copy mode) | Begin selection |
| `y` (copy mode) | Copy selection |

Mouse mode is enabled. Windows and panes are 1-indexed. True color and focus events are enabled for Neovim compatibility.

**Plugins installed via TPM:**
- `tmux-sensible` — sane defaults
- `tmux-resurrect` — save and restore sessions across reboots

---

## Zsh Plugins

| Plugin | Purpose |
|---|---|
| `zsh-autosuggestions` | Fish-style inline suggestions from history |
| `zsh-syntax-highlighting` | Command syntax highlighting |
| `fast-syntax-highlighting` | Faster alternative syntax highlighter |
| `zsh-autocomplete` | Real-time tab completion menu |

---

## Upgrading Tools

Tools installed from GitHub releases or go.dev won't auto-upgrade on re-runs. To upgrade a specific tool, remove its binary or directory and re-run the script:

| Tool | How to trigger reinstall |
|---|---|
| Neovim | `sudo rm -rf /opt/nvim-linux-x86_64` |
| Go | `sudo rm -rf /usr/local/go` |
| eza / glow / delta | `rm ~/.local/bin/<tool>` |
| fzf | `rm -rf ~/.fzf` |
| Starship | `rm $(which starship)` |

---

## Requirements

- Debian 12 (Bookworm) — tested on a fresh minimal install
- `sudo` access
- Internet connection
- SSH key added to GitHub (for cloning via `git@github.com`)

---

## Repository Structure

```
dotfiles/
├── install.sh      # Main setup script
└── README.md
```

---

## License

MIT
