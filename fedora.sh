#!/bin/bash
#
# Fedora Workstation Setup Script
# Sets up a fresh Fedora installation with development tools and zsh configuration
#
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)"
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root. It will prompt for sudo when needed."
    exit 1
fi

# Detect Linux distribution
log_info "Detecting Linux distribution..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
else
    log_error "Cannot detect Linux distribution (missing /etc/os-release)"
    exit 1
fi

# Check if running on Fedora
if [ "$DISTRO_ID" != "fedora" ]; then
    log_error "This script is designed for Fedora, but you're running: $DISTRO_ID"
    log_error ""
    case "$DISTRO_ID" in
        ubuntu)
            log_info "For Ubuntu, use this script instead:"
            log_info "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)\""
            ;;
        *)
            log_warn "No installation script is currently available for $DISTRO_ID"
            log_info "Available scripts:"
            log_info "  - Ubuntu: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh"
            log_info "  - Fedora: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh"
            ;;
    esac
    exit 1
fi

log_info "✓ Detected Fedora - continuing with setup..."
log_info "Starting Fedora workstation setup..."

# Config sourcing: copy from a local checkout when running from one, otherwise
# download from GitHub. Lets the same script work both ways:
#   bash -c "$(curl -fsSL .../fedora.sh)"  -> remote (no local config/ dir)
#   ./fedora.sh                            -> local (copies from ./config)
RAW_BASE_URL="https://raw.githubusercontent.com/marcoshack/install/refs/heads/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd 2>/dev/null || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/config/starship.toml" ]; then
    LOCAL_CONFIG_DIR="$SCRIPT_DIR/config"
    log_info "Running from a local checkout; config files will be copied from $LOCAL_CONFIG_DIR"
else
    LOCAL_CONFIG_DIR=""
    log_info "Running remotely; config files will be downloaded from GitHub"
fi

# fetch_config <relative-path-under-config/> <destination>
fetch_config() {
    if [ -n "$LOCAL_CONFIG_DIR" ] && [ -f "$LOCAL_CONFIG_DIR/$1" ]; then
        cp "$LOCAL_CONFIG_DIR/$1" "$2"
    else
        curl -fsSL "$RAW_BASE_URL/config/$1" -o "$2"
    fi
}

# Configuration file path
CONFIG_FILE="$HOME/.install.conf"

# Define available steps
log_info ""
log_info "Available installation steps:"
log_info "  1. System Update"
log_info "  2. Development Tools Installation"
log_info "  3. Git Configuration"
log_info "  4. SSH Key Generation"
log_info "  5. CLI Tools Installation (zsh, fzf, ripgrep, bat, tmux)"
log_info "  6. Go Installation"
log_info "  7. Rust Installation"
log_info "  8. Python Installation"
log_info "  9. Tmux Configuration"
log_info " 10. Starship and Zsh Plugins Installation"
log_info " 11. Zsh Configuration"
log_info " 12. Default Shell Change"
log_info " 13. Neovim Configuration (nvim-tree)"
log_info ""

# Initialize skip flags
SKIP_STEPS=""

# Check if config file exists
if [ -f "$CONFIG_FILE" ]; then
    log_info "Found existing configuration at $CONFIG_FILE"
    SAVED_SKIP_STEPS=$(cat "$CONFIG_FILE")
    log_info "Saved skip steps: $SAVED_SKIP_STEPS"
    read -p "Do you want to use this configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Ignoring saved configuration"
        USE_SAVED_CONFIG=false
    else
        log_info "Using saved configuration"
        SKIP_STEPS="$SAVED_SKIP_STEPS"
        USE_SAVED_CONFIG=true
    fi
else
    USE_SAVED_CONFIG=false
fi

# If not using saved config, prompt for steps to skip
if [ "$USE_SAVED_CONFIG" != true ]; then
    log_info "Enter the numbers of steps to skip (comma-separated, e.g., '3,4,8')."
    log_info "Press Enter to run all steps."
    read -p "Steps to skip: " SKIP_INPUT

    if [ -n "$SKIP_INPUT" ]; then
        SKIP_STEPS="$SKIP_INPUT"
        log_info ""
        read -p "Do you want to save this configuration for future use? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$SKIP_STEPS" > "$CONFIG_FILE"
            log_info "Configuration saved to $CONFIG_FILE"
        fi
    else
        log_info "No steps will be skipped"
    fi
fi

# Helper function to check if a step should be skipped
should_skip_step() {
    local step_num=$1
    if [ -z "$SKIP_STEPS" ]; then
        return 1
    fi

    IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_STEPS"
    for skip_num in "${SKIP_ARRAY[@]}"; do
        # Trim whitespace
        skip_num=$(echo "$skip_num" | xargs)
        if [ "$skip_num" = "$step_num" ]; then
            return 0
        fi
    done
    return 1
}

log_info ""
log_info "Starting installation..."
log_info ""

# Step 1: Update system
if should_skip_step 1; then
    log_warn "Skipping Step 1: System Update"
else
    log_info "Step 1: Updating system packages..."
    sudo dnf update -y
fi

# Step 2: Install development tools and utilities
if should_skip_step 2; then
    log_warn "Skipping Step 2: Development Tools Installation"
else
    log_info "Step 2: Installing development tools and utilities..."
    # Install EPEL and additional repositories if needed
    log_info "Ensuring required repositories are enabled..."
    sudo dnf install -y dnf-plugins-core

    # Install development tools and utilities
    log_info "Installing development tools and utilities..."
    sudo dnf install -y \
        gcc \
        gcc-c++ \
        make \
        automake \
        autoconf \
        libtool \
        pkgconfig \
        git \
        curl \
        wget \
        vim \
        htop \
        tmux \
        unzip \
        tar \
        gawk
fi

# Step 3: Configure Git
if should_skip_step 3; then
    log_warn "Skipping Step 3: Git Configuration"
else
    log_info "Step 3: Configuring Git..."

    CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

    if [ -n "$CURRENT_GIT_NAME" ] && [ -n "$CURRENT_GIT_EMAIL" ]; then
        log_info "Git is already configured:"
        log_info "  Name: $CURRENT_GIT_NAME"
        log_info "  Email: $CURRENT_GIT_EMAIL"
        read -p "Do you want to reconfigure Git? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing Git configuration"
            SKIP_GIT_CONFIG=true
        fi
    fi

    if [ "$SKIP_GIT_CONFIG" != true ]; then
        read -p "Enter your Git username: " GIT_NAME
        read -p "Enter your Git email: " GIT_EMAIL

        if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            log_info "✓ Git configured successfully"
            log_info "  Name: $GIT_NAME"
            log_info "  Email: $GIT_EMAIL"
        else
            log_warn "Git configuration skipped (empty values provided)"
        fi
    fi
fi

# Step 4: Generate SSH key for GitHub
if should_skip_step 4; then
    log_warn "Skipping Step 4: SSH Key Generation"
else
    log_info "Step 4: Setting up SSH key for GitHub..."
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

    if [ -f "$SSH_KEY_PATH" ]; then
        log_warn "SSH key already exists at $SSH_KEY_PATH"
        read -p "Do you want to generate a new SSH key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing SSH key"
            SKIP_SSH_KEYGEN=true
        fi
    fi

    if [ "$SKIP_SSH_KEYGEN" != true ]; then
        # Get email for SSH key (use git email if available)
        if [ -n "$GIT_EMAIL" ]; then
            SSH_EMAIL="$GIT_EMAIL"
        else
            SSH_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
        fi

        if [ -z "$SSH_EMAIL" ]; then
            read -p "Enter your email for SSH key: " SSH_EMAIL
        fi

        if [ -n "$SSH_EMAIL" ]; then
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"

            log_info "Generating SSH key..."
            ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""

            # Start ssh-agent and add key
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            ssh-add "$SSH_KEY_PATH" >/dev/null 2>&1

            log_info "✓ SSH key generated successfully"
            log_info ""
            log_info "=========================================="
            log_info "Your SSH public key:"
            log_info "=========================================="
            cat "${SSH_KEY_PATH}.pub"
            log_info "=========================================="
            log_info ""
            log_info "To add this key to GitHub:"
            log_info "1. Copy the key above"
            log_info "2. Go to https://github.com/settings/keys"
            log_info "3. Click 'New SSH key'"
            log_info "4. Paste your key and save"
            log_info ""
        else
            log_warn "SSH key generation skipped (no email provided)"
        fi
    fi
fi

# Step 5: Install zsh and related tools
if should_skip_step 5; then
    log_warn "Skipping Step 5: CLI Tools Installation (zsh, fzf, ripgrep, bat, fd, tmux)"
else
    log_info "Step 5: Installing zsh, fzf, ripgrep, bat, and fd..."
    sudo dnf install -y \
        zsh \
        fzf \
        ripgrep \
        bat \
        fd-find \
        util-linux-user
fi

# Step 6: Install Go
if should_skip_step 6; then
    log_warn "Skipping Step 6: Go Installation"
else
    log_info "Step 6: Installing Go..."
    sudo dnf install -y golang

    # Setup Go environment variables if not already set
    if ! grep -q "GOPATH" "$HOME/.profile" 2>/dev/null; then
        log_info "Adding Go environment to ~/.profile..."
        cat >> "$HOME/.profile" << 'EOF'

# Go language
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
    fi

    # Source the profile for current session
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin

    # Create Go workspace
    mkdir -p "$HOME/go"/{bin,src,pkg}
fi

# Step 7: Install Rust
if should_skip_step 7; then
    log_warn "Skipping Step 7: Rust Installation"
else
    log_info "Step 7: Installing Rust..."
    sudo dnf install -y rust cargo

    # Setup Rust environment variables if not already set
    if ! grep -q "CARGO_HOME" "$HOME/.profile" 2>/dev/null; then
        log_info "Adding Rust environment to ~/.profile..."
        cat >> "$HOME/.profile" << 'EOF'

# Rust language
export CARGO_HOME=$HOME/.cargo
export PATH=$PATH:$CARGO_HOME/bin
EOF
    fi

    # Source the profile for current session
    export CARGO_HOME=$HOME/.cargo
    export PATH=$PATH:$CARGO_HOME/bin
fi

# Step 8: Install Python and uv
if should_skip_step 8; then
    log_warn "Skipping Step 8: Python Installation"
else
    log_info "Step 8: Installing Python 3.14..."
    sudo dnf install -y python3.14 python3.14-pip python3.14-devel

    log_info "Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Add uv to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
fi

# Step 9: Configure tmux
if should_skip_step 9; then
    log_warn "Skipping Step 9: Tmux Configuration"
else
    log_info "Step 9: Setting up tmux configuration..."
    TMUX_CONF_PATH="$HOME/.tmux.conf"

    if [ -f "$TMUX_CONF_PATH" ]; then
        log_warn "tmux configuration already exists at $TMUX_CONF_PATH"
        read -p "Do you want to use the provided tmux.conf? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TMUX_CONF=true
        fi
    else
        read -p "Do you want to use the provided tmux.conf? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TMUX_CONF=true
        fi
    fi

    if [ "$INSTALL_TMUX_CONF" = true ]; then
        log_info "Installing tmux configuration..."
        fetch_config "tmux.conf" "$TMUX_CONF_PATH"
        log_info "✓ tmux configuration installed successfully"
    else
        log_info "Skipping tmux configuration"
    fi
fi

# Step 10: Install Starship and Zsh plugins
if should_skip_step 10; then
    log_warn "Skipping Step 10: Starship and Zsh Plugins Installation"
else
    log_info "Step 10: Installing Starship prompt and zsh plugins..."

    # Starship is packaged for Fedora; fall back to upstream installer if missing
    if ! command -v starship >/dev/null 2>&1; then
        if sudo dnf install -y starship; then
            log_info "✓ Starship installed via dnf"
        else
            log_warn "dnf install starship failed, using upstream installer"
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
        fi
    else
        log_info "Starship is already installed"
    fi

    log_info "Installing zsh-autosuggestions and zsh-syntax-highlighting..."
    sudo dnf install -y zsh-autosuggestions zsh-syntax-highlighting

    # Write starship config
    STARSHIP_CONFIG_DIR="$HOME/.config"
    STARSHIP_CONFIG_PATH="$STARSHIP_CONFIG_DIR/starship.toml"
    mkdir -p "$STARSHIP_CONFIG_DIR"

    if [ -f "$STARSHIP_CONFIG_PATH" ]; then
        log_warn "Starship config already exists at $STARSHIP_CONFIG_PATH - keeping existing config"
    else
        log_info "Installing Starship configuration..."
        fetch_config "starship.toml" "$STARSHIP_CONFIG_PATH"
        log_info "✓ Starship config written to $STARSHIP_CONFIG_PATH"
    fi
fi

# Step 11: Create/update .zshrc
if should_skip_step 11; then
    log_warn "Skipping Step 11: Zsh Configuration"
else
    log_info "Step 11: Configuring .zshrc..."
    cat > "$HOME/.zshrc" << 'EOF'
# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS SHARE_HISTORY

# Completion
autoload -Uz compinit && compinit

# Prompt
eval "$(starship init zsh)"

# Plugins
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Go environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Rust environment
export CARGO_HOME=$HOME/.cargo
export PATH=$PATH:$CARGO_HOME/bin

# Local bin (Python uv, starship if installed there)
export PATH="$HOME/.local/bin:$PATH"

# Editor
export EDITOR='vim'
export VISUAL='vim'

# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias cat='bat --style=plain --paging=never'
alias find='fd'

# fzf
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
EOF
fi

# Step 12: Change default shell to zsh
if should_skip_step 12; then
    log_warn "Skipping Step 12: Default Shell Change"
else
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Step 12: Changing default shell to zsh..."
        sudo chsh -s "$(which zsh)" "$USER"
        log_warn "You'll need to log out and back in for the shell change to take effect"
    else
        log_info "Step 12: Default shell is already zsh"
    fi
fi

# Step 13: Configure Neovim with nvim-tree
if should_skip_step 13; then
    log_warn "Skipping Step 13: Neovim Configuration"
else
    log_info "Step 13: Setting up Neovim with nvim-tree..."

    if ! command -v nvim >/dev/null 2>&1; then
        log_info "Installing Neovim via dnf..."
        sudo dnf install -y neovim
    else
        log_info "Neovim is already installed"
    fi

    NVIM_CONFIG_DIR="$HOME/.config/nvim"
    mkdir -p "$NVIM_CONFIG_DIR"

    if [ -f "$NVIM_CONFIG_DIR/init.lua" ]; then
        log_warn "Neovim config already exists at $NVIM_CONFIG_DIR/init.lua - keeping existing config"
    else
        log_info "Installing Neovim configuration..."
        fetch_config "nvim/init.lua" "$NVIM_CONFIG_DIR/init.lua"
        # Lockfile pins plugins to reviewed commits; best-effort (tolerate a 404 before first publish)
        fetch_config "nvim/lazy-lock.json" "$NVIM_CONFIG_DIR/lazy-lock.json" 2>/dev/null || \
            log_warn "Could not fetch lazy-lock.json; plugins will resolve to their latest stable tags"

        log_info "Installing Neovim plugins via lazy.nvim (this may take a moment)..."
        if [ -f "$NVIM_CONFIG_DIR/lazy-lock.json" ]; then
            nvim --headless "+Lazy! restore" +qa
        else
            nvim --headless "+Lazy! sync" +qa
        fi
        log_info "✓ Neovim configured with nvim-tree (toggle the file explorer with <leader>e)"
    fi
fi

# Verify installations
log_info "Verifying installations..."

command -v go >/dev/null 2>&1 && log_info "✓ Go: $(go version | awk '{print $3}')" || log_error "✗ Go installation failed"
command -v rustc >/dev/null 2>&1 && log_info "✓ Rust: $(rustc --version | awk '{print $2}')" || log_error "✗ Rust installation failed"
command -v cargo >/dev/null 2>&1 && log_info "✓ Cargo: $(cargo --version | awk '{print $2}')" || log_error "✗ Cargo installation failed"
command -v python3.14 >/dev/null 2>&1 && log_info "✓ Python: $(python3.14 --version | awk '{print $2}')" || log_error "✗ Python installation failed"
command -v uv >/dev/null 2>&1 && log_info "✓ uv: $(uv --version)" || log_error "✗ uv installation failed"
command -v zsh >/dev/null 2>&1 && log_info "✓ Zsh: $(zsh --version)" || log_error "✗ Zsh installation failed"
command -v fzf >/dev/null 2>&1 && log_info "✓ fzf installed" || log_error "✗ fzf installation failed"
command -v rg >/dev/null 2>&1 && log_info "✓ ripgrep installed" || log_error "✗ ripgrep installation failed"
command -v bat >/dev/null 2>&1 && log_info "✓ bat installed" || log_error "✗ bat installation failed"
command -v fd >/dev/null 2>&1 && log_info "✓ fd installed" || log_error "✗ fd installation failed"
command -v tmux >/dev/null 2>&1 && log_info "✓ tmux installed" || log_error "✗ tmux installation failed"
command -v starship >/dev/null 2>&1 && log_info "✓ Starship: $(starship --version | head -1)" || log_error "✗ Starship installation failed"
command -v nvim >/dev/null 2>&1 && log_info "✓ Neovim: $(nvim --version | head -1 | awk '{print $2}')" || log_error "✗ Neovim installation failed"

log_info ""
log_info "=========================================="
log_info "Setup completed successfully!"
log_info "=========================================="
log_info ""

# Display SSH public key if it exists
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    log_info "=========================================="
    log_info "Your SSH public key for GitHub:"
    log_info "=========================================="
    cat "${SSH_KEY_PATH}.pub"
    log_info "=========================================="
    log_info ""
    log_info "To add this key to GitHub:"
    log_info "1. Copy the key above"
    log_info "2. Go to https://github.com/settings/keys"
    log_info "3. Click 'New SSH key'"
    log_info "4. Paste your key and save"
    log_info ""
fi

log_info "Next steps:"
log_info "1. Log out and log back in (or reboot) for shell changes to take effect"
log_info "2. Run 'source ~/.zshrc' or start a new terminal session"
log_info "3. Verify Go installation with: go version"
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    log_info "4. Add your SSH key to GitHub (see above)"
fi
log_info ""
log_info "Installed tools:"
log_info "  - Go (via dnf)"
log_info "  - Rust (via dnf)"
log_info "  - Python 3.14 (via dnf)"
log_info "  - uv (Python package manager)"
log_info "  - Zsh with Starship prompt and plugins (autosuggestions, syntax highlighting)"
log_info "  - fzf (fuzzy finder)"
log_info "  - ripgrep (fast grep alternative)"
log_info "  - bat (cat with syntax highlighting)"
log_info "  - fd (fast find alternative)"
log_info "  - tmux (terminal multiplexer)"
log_info "  - Neovim with nvim-tree (managed by lazy.nvim, toggle with <leader>e)"
log_info ""
log_info "Git configuration:"
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Not configured")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not configured")
log_info "  - Name: $FINAL_GIT_NAME"
log_info "  - Email: $FINAL_GIT_EMAIL"
log_info ""
log_info "Happy coding!"