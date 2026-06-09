#!/bin/bash
#
# macOS Setup Script
# Sets up a fresh macOS installation with development tools and zsh configuration
#
# Usage: sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/macos.sh)"
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

# Check if running on macOS
if [ "$(uname)" != "Darwin" ]; then
    log_error "This script is designed for macOS, but you're running: $(uname)"
    log_error ""
    log_info "Available scripts for other platforms:"
    log_info "  - Ubuntu: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh"
    log_info "  - Fedora: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh"
    exit 1
fi

log_info "✓ Detected macOS $(sw_vers -productVersion) - continuing with setup..."
log_info "Starting macOS workstation setup..."

# Config sourcing: copy from a local checkout when running from one, otherwise
# download from GitHub. Lets the same script work both ways:
#   sh -c "$(curl -fsSL .../macos.sh)"   -> remote (no local config/ dir)
#   ./macos.sh                            -> local (copies from ./config)
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
log_info "  1. Xcode Command Line Tools"
log_info "  2. Homebrew Installation"
log_info "  3. Development Tools Installation"
log_info "  4. Git Configuration"
log_info "  5. SSH Key Generation"
log_info "  6. CLI Tools Installation (fzf, ripgrep, bat, glow, tmux)"
log_info "  7. Go Installation"
log_info "  8. Rust Installation"
log_info "  9. Python and uv Installation"
log_info " 10. Tmux Configuration"
log_info " 11. Starship and Zsh Plugins Installation"
log_info " 12. Zsh Configuration"
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

# Step 1: Install Xcode Command Line Tools
if should_skip_step 1; then
    log_warn "Skipping Step 1: Xcode Command Line Tools"
else
    log_info "Step 1: Checking Xcode Command Line Tools..."
    if xcode-select -p &>/dev/null; then
        log_info "✓ Xcode Command Line Tools already installed"
    else
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_info "Please complete the Xcode Command Line Tools installation in the popup window"
        log_info "Press Enter when the installation is complete..."
        read -r
    fi
fi

# Step 2: Install Homebrew
if should_skip_step 2; then
    log_warn "Skipping Step 2: Homebrew Installation"
else
    log_info "Step 2: Checking Homebrew..."
    if command -v brew &>/dev/null; then
        log_info "✓ Homebrew already installed"
        log_info "Updating Homebrew..."
        brew update
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for current session
        if [ -f "/opt/homebrew/bin/brew" ]; then
            # Apple Silicon
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            # Intel Mac
            eval "$(/usr/local/bin/brew shellenv)"
        fi

        log_info "✓ Homebrew installed successfully"
    fi
fi

# Ensure brew is in PATH for the rest of the script
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Step 3: Install development tools and utilities
if should_skip_step 3; then
    log_warn "Skipping Step 3: Development Tools Installation"
else
    log_info "Step 3: Installing development tools and utilities..."
    brew install \
        git \
        curl \
        wget \
        vim \
        htop \
        tmux \
        unzip \
        gnu-tar \
        gawk \
        coreutils \
        findutils \
        gnu-sed
fi

# Step 4: Configure Git
if should_skip_step 4; then
    log_warn "Skipping Step 4: Git Configuration"
else
    log_info "Step 4: Configuring Git..."

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

# Step 5: Generate SSH key for GitHub
if should_skip_step 5; then
    log_warn "Skipping Step 5: SSH Key Generation"
else
    log_info "Step 5: Setting up SSH key for GitHub..."
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

            # Add SSH key to macOS Keychain
            ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null || true

            log_info "✓ SSH key generated successfully"
            log_info ""
            log_info "=========================================="
            log_info "Your SSH public key:"
            log_info "=========================================="
            cat "${SSH_KEY_PATH}.pub"
            log_info "=========================================="
            log_info ""
            log_info "To add this key to GitHub:"
            log_info "1. Copy the key above (or run: pbcopy < ~/.ssh/id_ed25519.pub)"
            log_info "2. Go to https://github.com/settings/keys"
            log_info "3. Click 'New SSH key'"
            log_info "4. Paste your key and save"
            log_info ""
        else
            log_warn "SSH key generation skipped (no email provided)"
        fi
    fi
fi

# Step 6: Install CLI tools
if should_skip_step 6; then
    log_warn "Skipping Step 6: CLI Tools Installation (fzf, ripgrep, bat, glow, tmux)"
else
    log_info "Step 6: Installing fzf, ripgrep, bat, fd, and glow..."
    brew install \
        fzf \
        ripgrep \
        bat \
        fd \
        glow

    # Install fzf key bindings and completion
    log_info "Installing fzf key bindings..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
fi

# Step 7: Install Go
if should_skip_step 7; then
    log_warn "Skipping Step 7: Go Installation"
else
    log_info "Step 7: Installing Go..."
    brew install go

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

# Step 8: Install Rust
if should_skip_step 8; then
    log_warn "Skipping Step 8: Rust Installation"
else
    log_info "Step 8: Installing Rust via rustup..."

    if command -v rustc &>/dev/null; then
        log_warn "Rust is already installed"
        read -p "Do you want to reinstall Rust? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing Rust installation"
            SKIP_RUST_INSTALL=true
        fi
    fi

    if [ "$SKIP_RUST_INSTALL" != true ]; then
        # Install rustup-init via Homebrew and run it
        brew install rustup-init
        rustup-init -y --no-modify-path

        # Source cargo env for current session
        source "$HOME/.cargo/env"

        log_info "✓ Rust installed successfully"
    fi

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

# Step 9: Install Python and uv
if should_skip_step 9; then
    log_warn "Skipping Step 9: Python and uv Installation"
else
    log_info "Step 9: Installing Python and uv..."

    # Install uv via Homebrew (recommended for macOS)
    brew install uv

    # Use uv to install Python (latest stable)
    log_info "Installing Python via uv..."
    uv python install

    log_info "✓ Python and uv installed successfully"
fi

# Step 10: Configure tmux
if should_skip_step 10; then
    log_warn "Skipping Step 10: Tmux Configuration"
else
    log_info "Step 10: Setting up tmux configuration..."
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

# Step 11: Install Starship and Zsh plugins
if should_skip_step 11; then
    log_warn "Skipping Step 11: Starship and Zsh Plugins Installation"
else
    log_info "Step 11: Installing Starship prompt and zsh plugins..."
    brew install \
        starship \
        zsh-autosuggestions \
        zsh-syntax-highlighting

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

# Step 12: Create/update .zshrc
if should_skip_step 12; then
    log_warn "Skipping Step 12: Zsh Configuration"
else
    log_info "Step 12: Configuring .zshrc..."

    # Determine Homebrew prefix
    if [ -f "/opt/homebrew/bin/brew" ]; then
        BREW_PREFIX="/opt/homebrew"
    else
        BREW_PREFIX="/usr/local"
    fi

    cat > "$HOME/.zshrc" << EOF
# Homebrew
eval "\$(${BREW_PREFIX}/bin/brew shellenv)"

# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS SHARE_HISTORY

# Completion
autoload -Uz compinit && compinit

# Prompt
eval "\$(starship init zsh)"

# Plugins
source ${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Go environment
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOPATH/bin

# Rust environment
[ -f "\$HOME/.cargo/env" ] && source "\$HOME/.cargo/env"

# Local bin (Python uv etc.)
export PATH="\$HOME/.local/bin:\$PATH"

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
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
EOF
fi

# macOS doesn't need shell change step since zsh is default

# Step 13: Configure Neovim with nvim-tree
if should_skip_step 13; then
    log_warn "Skipping Step 13: Neovim Configuration"
else
    log_info "Step 13: Setting up Neovim with nvim-tree..."

    if ! command -v nvim >/dev/null 2>&1; then
        log_info "Installing Neovim via Homebrew..."
        brew install neovim
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
    fi

    # Install any plugins the config declares but that aren't installed yet. Runs on
    # every invocation (not just fresh installs) so re-running the script picks up
    # newly-added plugins. `+Lazy! restore` clones missing plugins and checks out the
    # lockfile commit; plugins already at the pinned commit are left untouched. The
    # existing init.lua is never overwritten, so local edits are preserved.
    log_info "Installing Neovim plugins via lazy.nvim (this may take a moment)..."
    if [ -f "$NVIM_CONFIG_DIR/lazy-lock.json" ]; then
        nvim --headless "+Lazy! restore" +qa
    else
        nvim --headless "+Lazy! sync" +qa
    fi
    log_info "✓ Neovim configured with nvim-tree (toggle the file explorer with <leader>e)"
fi

# Verify installations
log_info "Verifying installations..."

command -v brew >/dev/null 2>&1 && log_info "✓ Homebrew: $(brew --version | head -1)" || log_error "✗ Homebrew installation failed"
command -v go >/dev/null 2>&1 && log_info "✓ Go: $(go version | awk '{print $3}')" || log_error "✗ Go installation failed"
command -v rustc >/dev/null 2>&1 && log_info "✓ Rust: $(rustc --version | awk '{print $2}')" || log_error "✗ Rust installation failed"
command -v cargo >/dev/null 2>&1 && log_info "✓ Cargo: $(cargo --version | awk '{print $2}')" || log_error "✗ Cargo installation failed"
command -v uv >/dev/null 2>&1 && log_info "✓ uv: $(uv --version)" || log_error "✗ uv installation failed"
command -v python3 >/dev/null 2>&1 && log_info "✓ Python: $(python3 --version | awk '{print $2}')" || log_error "✗ Python installation failed"
command -v zsh >/dev/null 2>&1 && log_info "✓ Zsh: $(zsh --version)" || log_error "✗ Zsh installation failed"
command -v fzf >/dev/null 2>&1 && log_info "✓ fzf installed" || log_error "✗ fzf installation failed"
command -v rg >/dev/null 2>&1 && log_info "✓ ripgrep installed" || log_error "✗ ripgrep installation failed"
command -v bat >/dev/null 2>&1 && log_info "✓ bat installed" || log_error "✗ bat installation failed"
command -v fd >/dev/null 2>&1 && log_info "✓ fd installed" || log_error "✗ fd installation failed"
command -v glow >/dev/null 2>&1 && log_info "✓ glow installed" || log_error "✗ glow installation failed"
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
    log_info "1. Copy the key: pbcopy < ~/.ssh/id_ed25519.pub"
    log_info "2. Go to https://github.com/settings/keys"
    log_info "3. Click 'New SSH key'"
    log_info "4. Paste your key and save"
    log_info ""
fi

log_info "Next steps:"
log_info "1. Run 'source ~/.zshrc' or start a new terminal session"
log_info "2. Verify Go installation with: go version"
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    log_info "3. Add your SSH key to GitHub (see above)"
fi
log_info ""
log_info "Installed tools:"
log_info "  - Go (via Homebrew)"
log_info "  - Rust (via rustup)"
log_info "  - Python (via uv)"
log_info "  - uv (Python package manager)"
log_info "  - Zsh with Starship prompt and plugins (autosuggestions, syntax highlighting)"
log_info "  - fzf (fuzzy finder)"
log_info "  - ripgrep (fast grep alternative)"
log_info "  - bat (cat with syntax highlighting)"
log_info "  - fd (fast find alternative)"
log_info "  - glow (markdown reader)"
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
