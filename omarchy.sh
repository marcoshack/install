#!/bin/bash
#
# Omarchy Setup Script
# Sets up an Omarchy (Arch-based) installation with development tools and zsh configuration
#
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/omarchy.sh)"
#
# Unlike the other Linux scripts this does NOT chsh to zsh. Omarchy's session and
# tooling are built around bash (upstream recommends keeping it as the login
# shell), so bash stays the login shell and ~/.bashrc hands interactive terminals
# over to zsh. The zsh config itself comes from Omarchy's own `omarchy-zsh`
# package, so Omarchy updates keep the aliases, functions and keybindings current.
#

set -e

# This script is bash, but `sh -c "$(curl ...)"` ignores the shebang above. If
# /bin/sh is not bash, re-exec under bash: from the local file when running from
# a checkout, otherwise by re-fetching this script.
if [ -z "$BASH_VERSION" ]; then
    if ! command -v bash >/dev/null 2>&1; then
        echo "[ERROR] bash is required to run this script (sudo pacman -S bash)" >&2
        exit 1
    fi
    case "${0##*/}" in
        *.sh)
            if [ -f "$0" ]; then
                exec bash "$0" "$@"
            fi
            ;;
    esac
    SELF_URL="https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/omarchy.sh"
    SELF_SRC=$(curl -fsSL "$SELF_URL") || SELF_SRC=""
    if [ -z "$SELF_SRC" ]; then
        echo "[ERROR] Could not re-download this script from $SELF_URL" >&2
        exit 1
    fi
    exec bash -c "$SELF_SRC"
fi

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
if [ "$(id -u)" -eq 0 ]; then
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

# Check if running on Omarchy. Omarchy 4 reports ID=omarchy; older releases are
# plain Arch (ID=arch) with the omarchy-* commands on PATH.
if [ "$DISTRO_ID" != "omarchy" ] && ! { [ "$DISTRO_ID" = "arch" ] && command -v omarchy-pkg-add >/dev/null 2>&1; }; then
    log_error "This script is designed for Omarchy, but you're running: $DISTRO_ID"
    log_error ""
    case "$DISTRO_ID" in
        fedora)
            log_info "For Fedora, use this script instead:"
            log_info "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)\""
            ;;
        ubuntu)
            log_info "For Ubuntu, use this script instead:"
            log_info "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)\""
            ;;
        *)
            log_warn "No installation script is currently available for $DISTRO_ID"
            log_info "Available scripts:"
            log_info "  - Ubuntu: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh"
            log_info "  - Fedora: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh"
            log_info "  - Omarchy: https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/omarchy.sh"
            ;;
    esac
    exit 1
fi

if ! command -v omarchy-pkg-add >/dev/null 2>&1; then
    log_error "omarchy-pkg-add not found; this script needs Omarchy's package helpers"
    exit 1
fi

log_info "✓ Detected Omarchy - continuing with setup..."
log_info "Starting Omarchy workstation setup..."

# Config sourcing: copy from a local checkout when running from one, otherwise
# download from GitHub. Lets the same script work both ways:
#   bash -c "$(curl -fsSL .../omarchy.sh)"  -> remote (no local config/ dir)
#   ./omarchy.sh                            -> local (copies from ./config)
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
log_info "  1. System Update (omarchy update)"
log_info "  2. Development Tools Installation"
log_info "  3. Git Configuration"
log_info "  4. SSH Key Generation"
log_info "  5. CLI Tools Installation (zsh, fzf, ripgrep, bat, fd, glow)"
log_info "  6. Go Installation"
log_info "  7. Rust Installation"
log_info "  8. Python Installation"
log_info "  9. Tmux Configuration"
log_info " 10. Starship and Zsh Plugins Installation (omarchy-zsh)"
log_info " 11. Zsh Configuration"
log_info " 12. Zsh Terminal Handoff (bash stays the login shell)"
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
    log_info "Step 1: Updating system via omarchy update..."
    # Use Omarchy's updater rather than a bare `pacman -Syu`: it snapshots first,
    # updates the Omarchy repo packages and runs pending migrations.
    if command -v omarchy-update >/dev/null 2>&1; then
        # It may offer a reboot at the end; decline it so the remaining steps run.
        log_warn "If omarchy update offers a reboot, answer No; reboot after this script finishes"
        omarchy-update || log_warn "omarchy update did not complete; continuing"
    else
        sudo pacman -Syu --noconfirm
    fi
fi

# Step 2: Install development tools and utilities
if should_skip_step 2; then
    log_warn "Skipping Step 2: Development Tools Installation"
else
    log_info "Step 2: Installing development tools and utilities..."
    omarchy-pkg-add \
        base-devel \
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
    log_warn "Skipping Step 5: CLI Tools Installation (zsh, fzf, ripgrep, bat, fd, glow)"
else
    log_info "Step 5: Installing zsh, fzf, ripgrep, bat, fd, and glow..."
    # Most of these ship with Omarchy already; omarchy-pkg-add only installs what's missing
    omarchy-pkg-add \
        zsh \
        fzf \
        ripgrep \
        bat \
        fd \
        glow \
        eza \
        zoxide
fi

# Step 6: Install Go
if should_skip_step 6; then
    log_warn "Skipping Step 6: Go Installation"
else
    log_info "Step 6: Installing Go..."
    omarchy-pkg-add go

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

# Step 7: Install Rust via rustup
if should_skip_step 7; then
    log_warn "Skipping Step 7: Rust Installation"
else
    log_info "Step 7: Installing Rust via rustup..."
    if ! command -v rustc >/dev/null 2>&1; then
        omarchy-pkg-add rustup
        rustup default stable
        log_info "✓ Rust installed successfully"
    else
        log_info "Rust is already installed"
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

# Step 8: Install Python and uv
if should_skip_step 8; then
    log_warn "Skipping Step 8: Python Installation"
else
    # Arch tracks the latest CPython release, and uv is packaged in extra
    log_info "Step 8: Installing Python and uv..."
    omarchy-pkg-add python python-pip uv
fi

# Step 9: Configure tmux
if should_skip_step 9; then
    log_warn "Skipping Step 9: Tmux Configuration"
else
    log_info "Step 9: Setting up tmux configuration..."
    TMUX_CONF_PATH="$HOME/.tmux.conf"

    if [ -f "$TMUX_CONF_PATH" ]; then
        log_warn "tmux configuration already exists at $TMUX_CONF_PATH"
    fi
    # Omarchy keeps its own tmux config in ~/.config/tmux/tmux.conf; tmux only
    # reads that one when ~/.tmux.conf is absent, so installing ours overrides it.
    if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
        log_warn "Omarchy's tmux config (~/.config/tmux/tmux.conf) will be ignored by tmux if ~/.tmux.conf is installed"
    fi
    read -p "Do you want to use the provided tmux.conf? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_TMUX_CONF=true
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

    # omarchy-zsh (Omarchy's own package repo) ships Omarchy's zsh defaults under
    # /usr/share/omarchy-zsh and pulls in zsh-syntax-highlighting. Its
    # omarchy-setup-zsh helper is deliberately NOT run: it overwrites ~/.bashrc
    # wholesale; step 12 adds a marked handoff block instead.
    omarchy-pkg-add starship omarchy-zsh zsh-autosuggestions zsh-syntax-highlighting

    # Write starship config. Omarchy seeds ~/.config/starship.toml with its own
    # default, so offer to replace it only while it's still that untouched default.
    STARSHIP_CONFIG_DIR="$HOME/.config"
    STARSHIP_CONFIG_PATH="$STARSHIP_CONFIG_DIR/starship.toml"
    OMARCHY_STARSHIP_DEFAULT="${OMARCHY_PATH:-/usr/share/omarchy}/config/starship.toml"
    mkdir -p "$STARSHIP_CONFIG_DIR"

    INSTALL_STARSHIP_CONF=false
    if [ ! -f "$STARSHIP_CONFIG_PATH" ]; then
        INSTALL_STARSHIP_CONF=true
    elif [ -f "$OMARCHY_STARSHIP_DEFAULT" ] && cmp -s "$STARSHIP_CONFIG_PATH" "$OMARCHY_STARSHIP_DEFAULT"; then
        log_info "$STARSHIP_CONFIG_PATH is Omarchy's default Starship config"
        read -p "Do you want to replace it with the provided starship.toml? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_STARSHIP_CONF=true
        else
            log_info "Keeping Omarchy's Starship config"
        fi
    else
        log_warn "Starship config already exists at $STARSHIP_CONFIG_PATH - keeping existing config"
    fi

    if [ "$INSTALL_STARSHIP_CONF" = true ]; then
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

    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.$(date +%Y%m%d)"
        log_info "Backed up existing .zshrc to ~/.zshrc.$(date +%Y%m%d)"
    fi

    cat > "$HOME/.zshrc" << 'EOF'
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Omarchy defaults from the omarchy-zsh package: options, history, completion,
# keybindings, fzf widgets, syntax highlighting, Omarchy's aliases/functions, and
# mise/starship/zoxide/fzf init. Sourced from /usr/share so Omarchy updates to the
# package take effect without touching this file.
[[ -f /usr/share/omarchy-zsh/shell/zoptions ]] && source /usr/share/omarchy-zsh/shell/zoptions
[[ -f /usr/share/omarchy-zsh/shell/all ]] && source /usr/share/omarchy-zsh/shell/all

# omarchy-zsh's aliases lag behind Omarchy's bash ones (e.g. its `cx` runs claude
# with bypassPermissions, bash's uses auto mode). Omarchy's bash alias file is
# zsh-compatible, so layer it on top to track the current defaults.
[[ -f /usr/share/omarchy/default/bash/aliases ]] && source /usr/share/omarchy/default/bash/aliases

# bash stays the login shell on Omarchy, so $SHELL still says bash. Programs that
# spawn a shell from it (tmux panes, herdr, nvim :terminal) should get zsh.
export SHELL="${commands[zsh]:-$SHELL}"

# Terminals inject shell integration for the shell they launch, which was bash
# before it exec'd into zsh, so load the zsh side by hand.
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} && -r $GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration ]]; then
    builtin source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
fi
if [[ -n ${KITTY_INSTALLATION_DIR:-} && -r $KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration ]]; then
    export KITTY_SHELL_INTEGRATION="enabled"
    autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
    kitty-integration
    unfunction kitty-integration
fi

# Plugins (syntax highlighting is already loaded by omarchy-zsh)
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Go environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Rust environment
export CARGO_HOME=$HOME/.cargo
export PATH=$PATH:$CARGO_HOME/bin

# Local bin (uv tools, starship if installed there)
export PATH="$HOME/.local/bin:$PATH"

# Aliases (on top of Omarchy's: ls/lsa/lt via eza, cd via zoxide, ff, n, g, ...)
alias ll='ls -lah'
alias grep='grep --color=auto'
alias cat='bat --style=plain --paging=never'
EOF
fi

# Step 12: Hand interactive terminals to zsh (bash stays the login shell)
if should_skip_step 12; then
    log_warn "Skipping Step 12: Zsh Terminal Handoff"
else
    log_info "Step 12: Handing interactive terminals over to zsh..."
    BASHRC_PATH="$HOME/.bashrc"
    HANDOFF_BEGIN="# >>> zsh handoff (marcoshack/install omarchy.sh) >>>"
    HANDOFF_END="# <<< zsh handoff <<<"

    LOGIN_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    if [[ "$LOGIN_SHELL" == */zsh ]]; then
        log_warn "Your login shell is $LOGIN_SHELL. Omarchy expects bash as the login shell;"
        log_warn "to go back, run: chsh -s /usr/bin/bash"
    fi

    if grep -qF "$HANDOFF_BEGIN" "$BASHRC_PATH" 2>/dev/null; then
        log_info "zsh handoff already present in ~/.bashrc"
    else
        [ -f "$BASHRC_PATH" ] && cp "$BASHRC_PATH" "$BASHRC_PATH.$(date +%Y%m%d)"

        HANDOFF_FILE=$(mktemp)
        cat > "$HANDOFF_FILE" << EOF
$HANDOFF_BEGIN
# Omarchy's session and scripts expect bash as the login shell, so keep it and
# exec into zsh for interactive terminals instead. Stays bash for \`bash -c\`,
# for a bash started from a shell on purpose, and for nested shells (except
# tmux/herdr panes, whose long-lived server may have been started from bash).
# Delete this block to go back to bash.
if [[ \$- == *i* && -z \${BASH_EXECUTION_STRING:-} ]] && command -v zsh >/dev/null 2>&1; then
  _zsh_handoff_parent=\$(ps -o comm= -p "\$PPID" 2>/dev/null)
  if [[ \$_zsh_handoff_parent != zsh && \$_zsh_handoff_parent != bash ]] && [[ \${SHLVL:-1} == 1 || -n \${TMUX:-} || -n \${HERDR_PANE_ID:-} ]]; then
    unset _zsh_handoff_parent
    export SHELL=\$(command -v zsh)
    if shopt -q login_shell; then exec zsh --login; else exec zsh; fi
  fi
  unset _zsh_handoff_parent
fi
$HANDOFF_END
EOF

        # Insert right after Omarchy's "not interactive -> return" guard so the
        # env-bootstrap line above it keeps running for non-interactive shells.
        if grep -qxF '[[ $- != *i* ]] && return' "$BASHRC_PATH" 2>/dev/null; then
            awk -v f="$HANDOFF_FILE" '
                { print }
                !done && $0 == "[[ $- != *i* ]] && return" {
                    print ""
                    while ((getline line < f) > 0) print line
                    done = 1
                }' "$BASHRC_PATH" > "$BASHRC_PATH.tmp"
            mv "$BASHRC_PATH.tmp" "$BASHRC_PATH"
        else
            { echo; cat "$HANDOFF_FILE"; } >> "$BASHRC_PATH"
        fi
        rm -f "$HANDOFF_FILE"
        log_info "✓ Added zsh handoff to ~/.bashrc (backup: ~/.bashrc.$(date +%Y%m%d))"
    fi
    log_info "New terminal windows will open zsh; your login shell stays bash"
fi

# Step 13: Configure Neovim with nvim-tree
if should_skip_step 13; then
    log_warn "Skipping Step 13: Neovim Configuration"
else
    log_info "Step 13: Setting up Neovim with nvim-tree..."

    omarchy-pkg-add neovim

    NVIM_CONFIG_DIR="$HOME/.config/nvim"
    SETUP_NVIM=true

    # Omarchy ships LazyVim (with live theme sync) in ~/.config/nvim. Only replace
    # it on request; the old config/data are moved aside, and `omarchy-nvim-refresh`
    # restores Omarchy's default.
    if [ -f "$NVIM_CONFIG_DIR/lazyvim.json" ]; then
        log_warn "Omarchy's LazyVim config is installed at $NVIM_CONFIG_DIR"
        read -p "Replace it with the provided Neovim config (nvim-tree + Telescope)? Omarchy theme sync in Neovim will stop. (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            NVIM_BACKUP_SUFFIX="omarchy-backup-$(date +%Y%m%d-%H%M%S)"
            for dir in "$NVIM_CONFIG_DIR" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
                if [ -e "$dir" ]; then
                    mv "$dir" "$dir.$NVIM_BACKUP_SUFFIX"
                    log_info "Moved $dir to $dir.$NVIM_BACKUP_SUFFIX"
                fi
            done
        else
            log_info "Keeping Omarchy's Neovim config"
            SETUP_NVIM=false
        fi
    fi

    if [ "$SETUP_NVIM" = true ]; then
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
fi

# Verify installations
log_info "Verifying installations..."

command -v go >/dev/null 2>&1 && log_info "✓ Go: $(go version | awk '{print $3}')" || log_error "✗ Go installation failed"
command -v rustc >/dev/null 2>&1 && log_info "✓ Rust: $(rustc --version | awk '{print $2}')" || log_error "✗ Rust installation failed"
command -v cargo >/dev/null 2>&1 && log_info "✓ Cargo: $(cargo --version | awk '{print $2}')" || log_error "✗ Cargo installation failed"
command -v python3 >/dev/null 2>&1 && log_info "✓ Python: $(python3 --version | awk '{print $2}')" || log_error "✗ Python installation failed"
command -v uv >/dev/null 2>&1 && log_info "✓ uv: $(uv --version)" || log_error "✗ uv installation failed"
command -v zsh >/dev/null 2>&1 && log_info "✓ Zsh: $(zsh --version)" || log_error "✗ Zsh installation failed"
[ -f /usr/share/omarchy-zsh/shell/all ] && log_info "✓ omarchy-zsh installed" || log_error "✗ omarchy-zsh installation failed"
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
    log_info "1. Copy the key above"
    log_info "2. Go to https://github.com/settings/keys"
    log_info "3. Click 'New SSH key'"
    log_info "4. Paste your key and save"
    log_info ""
fi

log_info "Next steps:"
log_info "1. Open a new terminal window: it starts zsh (no logout needed, login shell stays bash)"
log_info "2. Verify Go installation with: go version"
if [ -f "${SSH_KEY_PATH}.pub" ]; then
    log_info "3. Add your SSH key to GitHub (see above)"
fi
log_info ""
log_info "Installed tools:"
log_info "  - Go (via pacman)"
log_info "  - Rust (via rustup)"
log_info "  - Python and uv (via pacman)"
log_info "  - Zsh with Omarchy's defaults (omarchy-zsh), Starship, autosuggestions, syntax highlighting"
log_info "  - fzf (fuzzy finder)"
log_info "  - ripgrep (fast grep alternative)"
log_info "  - bat (cat with syntax highlighting)"
log_info "  - fd (fast find alternative)"
log_info "  - glow (markdown reader)"
log_info "  - tmux (terminal multiplexer)"
log_info "  - Neovim"
log_info ""
log_info "Git configuration:"
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Not configured")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not configured")
log_info "  - Name: $FINAL_GIT_NAME"
log_info "  - Email: $FINAL_GIT_EMAIL"
log_info ""
log_info "Happy coding!"
