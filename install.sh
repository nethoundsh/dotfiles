#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installer — Debian 12 (Bookworm)
# Usage: ./install.sh [--dry-run]
# =============================================================================

set -euo pipefail

# --- Argument Parsing --------------------------------------------------------
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo ">>> DRY RUN mode — no changes will be made."
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [--dry-run]"
    exit 0
fi

# --- Helpers -----------------------------------------------------------------
log()  { echo "[+] $*"; }
warn() { echo "[!] WARNING: $*" >&2; }
run()  { if [[ "$DRY_RUN" == true ]]; then echo "    [dry-run] $*"; else "$@"; fi; }

# Runs a named block; on failure warns and records it but does NOT exit
FAILED_TOOLS=()
try_install() {
    local name="$1"
    shift
    if [[ "$DRY_RUN" == true ]]; then
        echo "    [dry-run] $name install block"
        return 0
    fi
    if ! "$@"; then
        warn "$name installation failed — skipping and continuing."
        FAILED_TOOLS+=("$name")
    fi
}

# Fetch the latest version tag from a GitHub repo (owner/repo), stripping leading 'v'
gh_latest() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' \
        | cut -d'"' -f4 \
        | tr -d 'v'
}

echo ""
echo "Starting Debian 12 dotfiles setup..."
echo ""

# =============================================================================
# 1. Base Packages & System Update
# =============================================================================
log "Updating packages and installing base tools..."
run sudo apt update
run sudo apt upgrade -y
run sudo apt install -y \
    git curl wget gpg unzip \
    zsh tmux htop btop \
    zoxide bat fd-find ripgrep \
    jq pipx python3-pip

# =============================================================================
# 2. Modern CLI Replacements & Symlinks
# =============================================================================

# Clean up dead eza apt repo from any previous install attempts
if [[ -f /etc/apt/sources.list.d/gierens.list ]]; then
    log "Removing stale eza apt source..."
    sudo rm -f /etc/apt/sources.list.d/gierens.list
    sudo rm -f /etc/apt/keyrings/gierens.gpg
    sudo apt update -qq
fi

# eza — GitHub releases ship tarballs only, no .deb; same temp dir pattern as glow/delta
if ! command -v eza &>/dev/null; then
    log "Installing eza from GitHub release..."
    _install_eza() {
        local tmpdir
        tmpdir=$(mktemp -d)
        curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
            | tar -xz -C "$tmpdir"
        local bin
        bin=$(find "$tmpdir" -type f -name "eza" | head -1)
        cp "$bin" ~/.local/bin/eza
        chmod +x ~/.local/bin/eza
        rm -rf "$tmpdir"
    }
    try_install "eza" _install_eza
else
    log "eza already installed. Skipping."
fi

# Fix Debian naming collisions — batcat -> bat, fdfind -> fd
log "Creating bat and fd symlinks..."
mkdir -p ~/.local/bin
ln -sf /usr/bin/batcat ~/.local/bin/bat
ln -sf /usr/bin/fdfind ~/.local/bin/fd

# glow — extract to temp dir first; tarball structure varies between releases
if ! command -v glow &>/dev/null; then
    log "Installing glow..."
    _install_glow() {
        GLOW_VER=$(gh_latest charmbracelet/glow)
        local tmpdir
        tmpdir=$(mktemp -d)
        curl -fsSL "https://github.com/charmbracelet/glow/releases/latest/download/glow_${GLOW_VER}_Linux_x86_64.tar.gz" \
            | tar -xz -C "$tmpdir"
        # Binary may be at root or inside a subdirectory — find it either way
        local bin
        bin=$(find "$tmpdir" -type f -name "glow" | head -1)
        cp "$bin" ~/.local/bin/glow
        chmod +x ~/.local/bin/glow
        rm -rf "$tmpdir"
    }
    try_install "glow" _install_glow
else
    log "glow already installed. Skipping."
fi

# delta — same temp dir pattern for safety
if ! command -v delta &>/dev/null; then
    log "Installing git-delta..."
    _install_delta() {
        DELTA_VER=$(gh_latest dandavison/delta)
        local tmpdir
        tmpdir=$(mktemp -d)
        curl -fsSL "https://github.com/dandavison/delta/releases/latest/download/delta-${DELTA_VER}-x86_64-unknown-linux-gnu.tar.gz" \
            | tar -xz -C "$tmpdir"
        local bin
        bin=$(find "$tmpdir" -type f -name "delta" | head -1)
        cp "$bin" ~/.local/bin/delta
        chmod +x ~/.local/bin/delta
        rm -rf "$tmpdir"
    }
    try_install "git-delta" _install_delta
else
    log "delta already installed. Skipping."
fi

# =============================================================================
# 3. Go (latest from go.dev)
# =============================================================================
if ! command -v go &>/dev/null; then
    log "Installing latest Go from go.dev..."
    _install_go() {
        GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
        curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        log "Go $GO_VERSION installed to /usr/local/go"
    }
    try_install "go" _install_go
else
    log "Go already installed ($(go version | awk '{print $3}')). Skipping."
    log "To upgrade, remove /usr/local/go and re-run."
fi

# =============================================================================
# 4. Neovim (GitHub Release) & Kickstart
# =============================================================================
if [[ ! -d "/opt/nvim-linux-x86_64" ]]; then
    log "Installing latest Neovim from GitHub..."
    _install_neovim() {
        sudo apt remove -y neovim neovim-runtime 2>/dev/null || true
        curl -fsSL -O https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
        sudo rm -rf /opt/nvim-linux-x86_64
        sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
        rm nvim-linux-x86_64.tar.gz
    }
    try_install "neovim" _install_neovim
else
    log "Neovim already installed at /opt/nvim-linux-x86_64. Skipping."
    log "To upgrade, delete /opt/nvim-linux-x86_64 and re-run."
fi

NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [[ ! -d "$NVIM_CONFIG_DIR" ]]; then
    log "Installing Kickstart.nvim config..."
    run mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
    run git clone https://github.com/nvim-lua/kickstart.nvim.git "$NVIM_CONFIG_DIR"
else
    log "Neovim config already exists at $NVIM_CONFIG_DIR. Skipping."
fi

# =============================================================================
# 5. fzf
# =============================================================================
# =============================================================================
# 5. fzf & Starship Prompt
# =============================================================================
if [[ ! -d "$HOME/.fzf" ]]; then
    log "Installing fzf..."
    _install_fzf() {
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
    }
    try_install "fzf" _install_fzf
else
    log "fzf already installed. Skipping."
fi

if ! command -v starship &>/dev/null; then
    log "Installing Starship prompt..."
    _install_starship() {
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    }
    try_install "starship" _install_starship
else
    log "Starship already installed. Skipping."
fi

# =============================================================================
# 7. Tmux — TPM & Config
# =============================================================================
log "Configuring tmux and installing TPM..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    run git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    log "TPM already installed. Skipping."
fi

[[ -f ~/.tmux.conf ]] && cp ~/.tmux.conf ~/.tmux.conf.bak

if [[ "$DRY_RUN" == false ]]; then
cat << 'EOF' > ~/.tmux.conf
set -g prefix C-a
unbind C-b
bind C-a send-prefix

set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set-option -g renumber-windows on

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded!"

set -sg escape-time 10
set-option -g focus-events on
set-option -g default-terminal "screen-256color"
set-option -a terminal-features 'xterm-256color:RGB'

set-window-option -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'

run '~/.tmux/plugins/tpm/tpm'
EOF
else
    echo "    [dry-run] write ~/.tmux.conf"
fi

# =============================================================================
# 8. Zsh — Oh My Zsh, Plugins & .zshrc
# =============================================================================
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    _install_omz() {
        env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    }
    try_install "oh-my-zsh" _install_omz
else
    log "Oh My Zsh already installed. Skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

log "Installing Zsh plugins..."
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] \
    && run git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
    || log "zsh-autosuggestions already present."

[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] \
    && run git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
    || log "zsh-syntax-highlighting already present."

[[ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]] \
    && run git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" \
    || log "fast-syntax-highlighting already present."

[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]] \
    && run git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM/plugins/zsh-autocomplete" \
    || log "zsh-autocomplete already present."

# Backup .zshrc, then patch it
[[ -f ~/.zshrc ]] && cp ~/.zshrc ~/.zshrc.bak

# Replace any existing plugins= line (handles prior runs and OMZ defaults)
run sed -i '/^plugins=/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)' ~/.zshrc

# Append PATH, aliases, and tool inits only once (guard on zoxide)
if ! grep -q "zoxide init zsh" ~/.zshrc; then
    log "Appending PATH and tool config to .zshrc..."
    if [[ "$DRY_RUN" == false ]]; then
    cat << 'EOF' >> ~/.zshrc

# =============================================================================
# Custom Config
# =============================================================================

# PATH — local bins, Neovim, Go toolchain
export PATH="$HOME/.local/bin:/opt/nvim-linux-x86_64/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

# Tool initialisation
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# Aliases
alias ls='eza --icons=always'
alias ll='eza -lh --icons=always'
alias la='eza -lah --icons=always'
alias cat='bat --paging=never'
alias grep='rg'
alias find='fd'
EOF
    else
        echo "    [dry-run] append PATH, evals, and aliases to ~/.zshrc"
    fi
fi

# =============================================================================
# 9. Finalization
# =============================================================================
log "Installing tmux plugins headlessly..."
~/.tmux/plugins/tpm/bin/install_plugins || true

if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    log "Changing default shell to Zsh..."
    run sudo chsh -s "$(command -v zsh)" "$USER"
else
    log "Default shell is already Zsh."
fi

echo ""
echo "======================================================================"
echo "  Setup complete!"
if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    echo ""
    echo "  The following tools failed to install and were skipped:"
    for tool in "${FAILED_TOOLS[@]}"; do
        echo "    - $tool"
    done
    echo ""
    echo "  Re-run with --only or manually install the above tools."
fi
echo ""
echo "  Run 'exec zsh' or log out/in to apply all changes."
echo "  Then run 'nvim' to let Kickstart initialize your plugins."
echo "======================================================================"
