#!/bin/bash
#
# Fedora Workstation Setup Script
# Sets up a fresh Fedora installation with development tools and zsh configuration
#
# Usage: curl -fsSL https://gist.githubusercontent.com/YOUR_USERNAME/GIST_ID/raw/fedora-setup.sh | bash
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

log_info "Starting Fedora workstation setup..."

# Update system
log_info "Updating system packages..."
sudo dnf update -y

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

# Configure Git
log_info "Configuring Git..."

# Force git to use HTTPS instead of SSH for GitHub (SSH key not yet on GitHub)
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://

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

# Generate SSH key for GitHub
log_info "Setting up SSH key for GitHub..."
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

# Install zsh and related tools
log_info "Installing zsh, fzf, ripgrep, and bat..."
sudo dnf install -y \
    zsh \
    fzf \
    ripgrep \
    bat \
    util-linux-user

# Install Go
log_info "Installing Go..."
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

# Install Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    log_warn "Oh My Zsh is already installed"
    read -p "Do you want to reinstall Oh My Zsh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing Oh My Zsh installation..."
        rm -rf "$HOME/.oh-my-zsh"
        INSTALL_OMZ=true
    fi
else
    INSTALL_OMZ=true
fi

if [ "$INSTALL_OMZ" = true ]; then
    log_info "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install zsh-autosuggestions plugin
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    log_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi

# Install zsh-syntax-highlighting plugin
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    log_info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
fi

# Create/update .zshrc
log_info "Configuring .zshrc..."
cat > "$HOME/.zshrc" << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    golang
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration

# Go environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

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

# fzf configuration
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

EOF

# Change default shell to zsh if not already
if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Changing default shell to zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
    log_warn "You'll need to log out and back in for the shell change to take effect"
fi

# Verify installations
log_info "Verifying installations..."

command -v go >/dev/null 2>&1 && log_info "✓ Go: $(go version | awk '{print $3}')" || log_error "✗ Go installation failed"
command -v zsh >/dev/null 2>&1 && log_info "✓ Zsh: $(zsh --version)" || log_error "✗ Zsh installation failed"
command -v fzf >/dev/null 2>&1 && log_info "✓ fzf installed" || log_error "✗ fzf installation failed"
command -v rg >/dev/null 2>&1 && log_info "✓ ripgrep installed" || log_error "✗ ripgrep installation failed"
command -v bat >/dev/null 2>&1 && log_info "✓ bat installed" || log_error "✗ bat installation failed"
[ -d "$HOME/.oh-my-zsh" ] && log_info "✓ Oh My Zsh installed" || log_error "✗ Oh My Zsh installation failed"

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
    log_info "After adding your SSH key to GitHub, enable SSH for git:"
    log_info "  git config --global --unset url.\"https://github.com/\".insteadOf"
    log_info "  git config --global --unset url.\"https://\".insteadOf"
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
log_info "  - Zsh with Oh My Zsh"
log_info "  - fzf (fuzzy finder)"
log_info "  - ripgrep (fast grep alternative)"
log_info "  - bat (cat with syntax highlighting)"
log_info ""
log_info "Git configuration:"
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Not configured")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not configured")
log_info "  - Name: $FINAL_GIT_NAME"
log_info "  - Email: $FINAL_GIT_EMAIL"
log_info ""
log_info "Happy coding!"