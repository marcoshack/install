#!/bin/bash
#
# macOS Setup Script
# Sets up a fresh macOS installation with development tools and zsh configuration
#
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/macos.sh)"
#
# Re-runs detect what is already set up and default to applying only new or
# missing steps. Options: --status, --new-only, --all (append after `_` when
# running remotely: bash -c "$(curl ...)" _ --new-only).
#

set -e

# This script is bash, but `sh -c "$(curl ...)"` ignores the shebang above. If
# /bin/sh is not bash, re-exec under bash: from the local file when running from
# a checkout, otherwise by re-fetching this script.
if [ -z "$BASH_VERSION" ]; then
    if ! command -v bash >/dev/null 2>&1; then
        echo "[ERROR] bash is required to run this script" >&2
        exit 1
    fi
    case "${0##*/}" in
        *.sh)
            if [ -f "$0" ]; then
                exec bash "$0" "$@"
            fi
            ;;
    esac
    SELF_URL="https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/macos.sh"
    SELF_SRC=$(curl -fsSL "$SELF_URL") || SELF_SRC=""
    if [ -z "$SELF_SRC" ]; then
        echo "[ERROR] Could not re-download this script from $SELF_URL" >&2
        exit 1
    fi
    exec bash -c "$SELF_SRC" bash "$@"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
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
#   bash -c "$(curl -fsSL .../macos.sh)" -> remote (no local config/ dir)
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

# ---------------------------------------------------------------------------
# Step catalogue, status detection and run menu
#
# Before running anything, every step is checked against the machine and shown
# as done / partial / missing / outdated. The default action applies only the
# steps that are not done, so re-running the script after new tools are added
# to it installs just those. Note: /bin/bash on macOS is 3.2, so no associative
# arrays or mapfile below.
# ---------------------------------------------------------------------------

# Steps listed here never run on this machine (comma-separated step numbers).
# Same file and format as the old "steps to skip" list, so saved lists still work.
CONFIG_FILE="$HOME/.install.conf"

# Bump ZSHRC_VERSION whenever the .zshrc generated in step 12 changes, so
# machines with an older copy show it as outdated.
ZSHRC_VERSION=2
ZSHRC_MARKER="# managed-by: marcoshack/install macos.sh zshrc"

# Package lists are shared by the install steps and the status checks, so adding
# a tool here is enough for re-runs to detect and install it.
DEV_TOOLS="git curl wget vim htop tmux unzip gnu-tar gawk coreutils findutils gnu-sed"
CLI_TOOLS="fzf ripgrep bat fd eza glow"
STARSHIP_PKGS="starship zsh-autosuggestions zsh-syntax-highlighting"

STEP_COUNT=14
STEP_NAMES=(
    ""
    "Xcode Command Line Tools"
    "Homebrew"
    "Development tools"
    "Git configuration"
    "SSH key for GitHub"
    "CLI tools"
    "Go"
    "Rust"
    "Python and uv"
    "tmux configuration"
    "Starship and zsh plugins"
    "Zsh configuration"
    "Neovim and plugins"
    "herdr"
)
STEP_STATE=()
STEP_DETAIL=()

usage() {
    echo "Usage: macos.sh [--status | --new-only | --all]"
    echo "  (no option)  show what is already set up, then ask what to run"
    echo "  --status     only show what is already set up"
    echo "  --new-only   run only the steps that are not done yet, without asking"
    echo "  --all        run every step except those listed in ~/.install.conf"
    echo "Remote: bash -c \"\$(curl -fsSL <url>/macos.sh)\" _ --new-only"
}

MODE=""
for arg in "$@"; do
    case "$arg" in
        --status) MODE=status ;;
        --new-only|--update) MODE=new ;;
        --all) MODE=all ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# Put Homebrew on PATH (if installed) so the checks below can see it
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

BREW_FORMULAE=" "
load_brew_formulae() {
    BREW_FORMULAE=" "
    if command -v brew >/dev/null 2>&1; then
        BREW_FORMULAE=" $(brew list --formula -1 2>/dev/null | tr '\n' ' ') "
    fi
}

# missing_formulae "<pkg> <pkg> ..." -> prints the ones Homebrew hasn't installed
missing_formulae() {
    local out="" f
    for f in $1; do
        case "$BREW_FORMULAE" in
            *" $f "*) ;;
            *) out="$out $f" ;;
        esac
    done
    echo "${out# }"
}

set_state() {
    STEP_STATE[$1]=$2
    STEP_DETAIL[$1]=$3
}

# check_formulae <step> "<pkgs>": done, missing (none installed) or partial
check_formulae() {
    local m
    m=$(missing_formulae "$2")
    if [ -z "$m" ]; then
        set_state "$1" "done" ""
    elif [ "$m" = "$(echo $2)" ]; then
        set_state "$1" missing ""
    else
        set_state "$1" partial "missing: $m"
    fi
}

zshrc_version() {
    sed -n "s|^$ZSHRC_MARKER v\([0-9][0-9]*\).*|\1|p" "$HOME/.zshrc" 2>/dev/null | head -1
}

# Plugins pinned in the deployed lazy-lock.json that lazy.nvim hasn't installed
missing_nvim_plugins() {
    local lock="$HOME/.config/nvim/lazy-lock.json"
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
    local out="" p
    [ -f "$lock" ] || return 0
    for p in $(sed -n 's/^ *"\([^"]*\)": *{.*/\1/p' "$lock"); do
        [ -d "$dir/$p" ] || out="$out $p"
    done
    echo "${out# }"
}

# --- Shipped config files (config/ in the repo) -------------------------------
# A deployed config can differ from the repo copy because the repo changed, or
# because it was edited locally (e.g. herdr's local-first workflow, or
# `:Lazy update` rewriting lazy-lock.json). To tell these apart, the hash of the
# repo version last deployed or offered is recorded in $CONFIG_STATE_DIR:
#   deployed == repo                 -> same     (done)
#   recorded == repo, deployed edited -> kept     (done, local edits kept)
#   nothing recorded, deployed != repo -> differs  (offer the repo version)
#   recorded != repo, deployed == recorded -> outdated (repo has a newer version)
#   recorded != repo, deployed edited  -> edited   (newer version + local edits)
# Declining an offer records the repo hash, so it isn't offered again until the
# repo copy changes.
CONFIG_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/marcoshack-install"
REPO_CONFIG_CACHE=$(mktemp -d)
trap 'rm -rf "$REPO_CONFIG_CACHE"' EXIT

# repo_config <rel>: prints the path of a cached copy of config/<rel>
repo_config() {
    local cached
    cached="$REPO_CONFIG_CACHE/$(echo "$1" | tr '/' '_')"
    if [ ! -f "$cached" ]; then
        fetch_config "$1" "$cached" 2>/dev/null || { rm -f "$cached"; return 1; }
    fi
    echo "$cached"
}

# config_hash <file> [ignore-regex]: hash ignoring lines tools add on their own
config_hash() {
    if [ -n "${2:-}" ]; then
        grep -Ev "$2" "$1" | shasum -a 256 | cut -d' ' -f1
    else
        shasum -a 256 < "$1" | cut -d' ' -f1
    fi
}

pretty_path() {
    case "$1" in
        "$HOME"/*) echo "~${1#"$HOME"}" ;;
        *) echo "$1" ;;
    esac
}

config_state_file() {
    echo "$CONFIG_STATE_DIR/$(echo "$1" | tr '/' '_').sha256"
}

record_config() {
    mkdir -p "$CONFIG_STATE_DIR"
    echo "$2" > "$(config_state_file "$1")"
}

# config_status <rel> <dest> [ignore-regex]
#   -> missing | same | kept | differs | outdated | edited | unknown
config_status() {
    local repo repo_hash dest_hash recorded
    [ -f "$2" ] || { echo missing; return; }
    repo=$(repo_config "$1") || { echo unknown; return; }
    repo_hash=$(config_hash "$repo" "${3:-}")
    dest_hash=$(config_hash "$2" "${3:-}")
    recorded=$(cat "$(config_state_file "$1")" 2>/dev/null || true)
    if [ "$dest_hash" = "$repo_hash" ]; then
        # Record the baseline on machines set up before this tracking existed,
        # so a later repo change can be told apart from a local edit
        [ -n "$recorded" ] || record_config "$1" "$repo_hash"
        echo same
    elif [ "$recorded" = "$repo_hash" ]; then
        echo kept
    elif [ -z "$recorded" ]; then
        echo differs
    elif [ "$dest_hash" = "$recorded" ]; then
        echo outdated
    else
        echo edited
    fi
}

# config_step_state <step> <rel> <dest> [ignore-regex]: downgrades a "done"
# step to "outdated" when the repo has a version of this config to offer
config_step_state() {
    local st detail=""
    st=$(config_status "$2" "$3" "${4:-}")
    case "$st" in
        differs) detail="$(pretty_path "$3") differs from the repo" ;;
        outdated) detail="newer $(pretty_path "$3") in the repo" ;;
        edited) detail="newer $(pretty_path "$3") in the repo; yours has local edits" ;;
        *) return 0 ;;
    esac
    if [ "${STEP_STATE[$1]}" = "done" ]; then
        set_state "$1" outdated "$detail"
    else
        STEP_DETAIL[$1]="${STEP_DETAIL[$1]:+${STEP_DETAIL[$1]}; }$detail"
    fi
}

# sync_config <rel> <dest> [ignore-regex]: install a missing config, or show a
# diff and offer the repo version when it changed. Never replaces silently.
sync_config() {
    local rel=$1 dest=$2 ign=${3:-} repo st backup
    st=$(config_status "$rel" "$dest" "$ign")
    if [ "$st" = unknown ]; then
        log_warn "Could not fetch config/$rel; leaving $dest as it is"
        return 0
    fi
    repo=$(repo_config "$rel")
    case "$st" in
        missing)
            mkdir -p "$(dirname "$dest")"
            cp "$repo" "$dest"
            record_config "$rel" "$(config_hash "$repo" "$ign")"
            log_info "✓ Installed $dest"
            ;;
        same)
            record_config "$rel" "$(config_hash "$repo" "$ign")"
            log_info "✓ $dest is up to date"
            ;;
        kept)
            log_info "✓ $dest has local edits; the repo version hasn't changed since it was last offered"
            ;;
        *)
            case "$st" in
                outdated) log_info "The repo has a newer $dest:" ;;
                edited) log_warn "The repo has a newer $dest, and yours has local edits:" ;;
                differs) log_info "$dest differs from the repo version:" ;;
            esac
            log_info "(- yours, + repo)"
            diff -u "$dest" "$repo" | tail -n +3 || true
            read -p "Replace $dest with the repo version? A backup is kept. (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup="$dest.backup-$(date +%Y%m%d-%H%M%S)"
                cp "$dest" "$backup"
                cp "$repo" "$dest"
                log_info "✓ Updated $dest (backup: $backup)"
            else
                log_info "Kept your $dest; this version won't be offered again"
            fi
            record_config "$rel" "$(config_hash "$repo" "$ign")"
            ;;
    esac
}

HERDR_CONF_IGNORE='^onboarding *='
ALIASES_HOOK='[ -f ~/.config/shell/aliases ] && . ~/.config/shell/aliases'

check_step() {
    local m v
    case $1 in
        1)
            if xcode-select -p >/dev/null 2>&1; then set_state 1 "done" ""; else set_state 1 missing ""; fi ;;
        2)
            if command -v brew >/dev/null 2>&1; then set_state 2 "done" ""; else set_state 2 missing ""; fi ;;
        3)
            check_formulae 3 "$DEV_TOOLS" ;;
        4)
            if [ -n "$(git config --global user.name 2>/dev/null)" ] && [ -n "$(git config --global user.email 2>/dev/null)" ]; then
                set_state 4 "done" "$(git config --global user.name)"
            else
                set_state 4 missing ""
            fi ;;
        5)
            if [ -f "$HOME/.ssh/id_ed25519" ]; then set_state 5 "done" ""; else set_state 5 missing ""; fi ;;
        6)
            check_formulae 6 "$CLI_TOOLS"
            if [ "${STEP_STATE[6]}" = "done" ] && [ ! -f "$HOME/.fzf.zsh" ]; then
                set_state 6 partial "fzf key bindings not installed"
            fi ;;
        7)
            check_formulae 7 "go"
            if [ "${STEP_STATE[7]}" = "done" ] && ! grep -q "GOPATH" "$HOME/.profile" 2>/dev/null; then
                set_state 7 partial "GOPATH not in ~/.profile"
            fi ;;
        8)
            if ! command -v rustc >/dev/null 2>&1 && [ ! -x "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/rustup/bin/rustc" ] && [ ! -x "$HOME/.cargo/bin/rustc" ]; then
                set_state 8 missing ""
            elif ! grep -q "CARGO_HOME" "$HOME/.profile" 2>/dev/null; then
                set_state 8 partial "CARGO_HOME not in ~/.profile"
            else
                set_state 8 "done" ""
            fi ;;
        9)
            check_formulae 9 "uv"
            if [ "${STEP_STATE[9]}" = "done" ] && ! compgen -G "$(uv python dir 2>/dev/null)/cpython-*" >/dev/null; then
                set_state 9 partial "no uv-managed Python"
            fi ;;
        10)
            if [ -f "$HOME/.tmux.conf" ]; then
                set_state 10 "done" ""
                config_step_state 10 "tmux.conf" "$HOME/.tmux.conf"
            else
                set_state 10 missing "optional"
            fi ;;
        11)
            check_formulae 11 "$STARSHIP_PKGS"
            if [ ! -f "$HOME/.config/starship.toml" ]; then
                if [ "${STEP_STATE[11]}" = "done" ]; then set_state 11 partial "no ~/.config/starship.toml"; fi
            else
                config_step_state 11 "starship.toml" "$HOME/.config/starship.toml"
            fi ;;
        12)
            v=$(zshrc_version)
            if [ ! -f "$HOME/.zshrc" ]; then
                set_state 12 missing ""
            elif [ -z "$v" ]; then
                set_state 12 outdated "not written by this script, or older than v1"
            elif [ "$v" -lt "$ZSHRC_VERSION" ]; then
                set_state 12 outdated "v$v -> v$ZSHRC_VERSION"
            else
                set_state 12 "done" "v$v"
            fi
            if [ ! -f "$HOME/.config/shell/aliases" ]; then
                if [ "${STEP_STATE[12]}" = "done" ]; then set_state 12 partial "no ~/.config/shell/aliases"; fi
            else
                config_step_state 12 "aliases" "$HOME/.config/shell/aliases"
            fi
            if [ "${STEP_STATE[12]}" = "done" ] && ! grep -qxF "$ALIASES_HOOK" "$HOME/.bashrc" 2>/dev/null; then
                # shellcheck disable=SC2088 # display text, not a path
                set_state 12 partial "~/.bashrc doesn't source the shared aliases"
            fi ;;
        13)
            if ! command -v nvim >/dev/null 2>&1; then
                set_state 13 missing ""
            elif [ ! -f "$HOME/.config/nvim/init.lua" ]; then
                set_state 13 partial "no ~/.config/nvim/init.lua"
            else
                m=$(missing_nvim_plugins)
                if [ -n "$m" ]; then set_state 13 partial "plugins not installed: $m"; else set_state 13 "done" ""; fi
                config_step_state 13 "nvim/init.lua" "$HOME/.config/nvim/init.lua"
                config_step_state 13 "nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
            fi ;;
        14)
            if ! command -v herdr >/dev/null 2>&1; then
                set_state 14 missing ""
            elif [ ! -f "$HOME/.config/herdr/config.toml" ]; then
                set_state 14 partial "no ~/.config/herdr/config.toml"
            else
                set_state 14 "done" ""
                config_step_state 14 "herdr/config.toml" "$HOME/.config/herdr/config.toml" "$HERDR_CONF_IGNORE"
            fi ;;
    esac
}

# in_list <n> "<comma list>"
in_list() {
    case ",$(echo "$2" | tr -d ' ')," in
        *",$1,"*) return 0 ;;
    esac
    return 1
}

NEVER_STEPS=""
load_never_steps() {
    NEVER_STEPS=""
    if [ -f "$CONFIG_FILE" ]; then
        NEVER_STEPS=$(tr -d ' \n' < "$CONFIG_FILE")
    fi
}

save_never_steps() {
    if [ -n "$NEVER_STEPS" ]; then
        echo "$NEVER_STEPS" > "$CONFIG_FILE"
    else
        rm -f "$CONFIG_FILE"
    fi
}

# add_never <n>: remember that step <n> should not be offered again
add_never() {
    in_list "$1" "$NEVER_STEPS" && return 0
    NEVER_STEPS="${NEVER_STEPS:+$NEVER_STEPS,}$1"
    save_never_steps
    log_info "Step $1 won't be offered again on this machine (remove it from $CONFIG_FILE to undo)"
}

PENDING_STEPS=""
refresh_status() {
    local n
    load_brew_formulae
    load_never_steps
    PENDING_STEPS=""
    for ((n = 1; n <= STEP_COUNT; n++)); do
        check_step "$n"
        if [ "${STEP_STATE[$n]}" != "done" ] && ! in_list "$n" "$NEVER_STEPS"; then
            PENDING_STEPS="${PENDING_STEPS:+$PENDING_STEPS,}$n"
        fi
    done
}

print_status() {
    local n color icon label detail
    echo ""
    printf "  %3s  %-26s %s\n" "#" "Step" "Status"
    for ((n = 1; n <= STEP_COUNT; n++)); do
        detail="${STEP_DETAIL[$n]}"
        case "${STEP_STATE[$n]}" in
            "done") color=$GREEN; icon="✓"; label="done" ;;
            partial) color=$YELLOW; icon="◐"; label="partial" ;;
            outdated) color=$YELLOW; icon="↑"; label="outdated" ;;
            *) color=$RED; icon="✗"; label="missing" ;;
        esac
        if in_list "$n" "$NEVER_STEPS"; then
            color=$GRAY
            label="$label, never run here"
        fi
        printf "  %3d  %-26s ${color}%s %s${NC}%b\n" "$n" "${STEP_NAMES[$n]}" "$icon" "$label" "${detail:+ ${GRAY}($detail)${NC}}"
    done
    echo ""
}

all_steps_except_never() {
    local n out=""
    for ((n = 1; n <= STEP_COUNT; n++)); do
        in_list "$n" "$NEVER_STEPS" || out="${out:+$out,}$n"
    done
    echo "$out"
}

# valid_step_list "<input>": 0 when every entry is a step number
valid_step_list() {
    local IFS=',' s
    for s in $(echo "$1" | tr -d ' '); do
        case "$s" in
            ''|*[!0-9]*) return 1 ;;
        esac
        [ "$s" -ge 1 ] && [ "$s" -le "$STEP_COUNT" ] || return 1
    done
    return 0
}

refresh_status
print_status

RUN_STEPS=""
case "$MODE" in
    status)
        if [ -n "$PENDING_STEPS" ]; then
            log_info "Steps not done yet: $PENDING_STEPS (run with --new-only to apply them)"
        else
            log_info "Everything is set up."
        fi
        exit 0
        ;;
    new)
        RUN_STEPS="$PENDING_STEPS"
        ;;
    all)
        RUN_STEPS=$(all_steps_except_never)
        ;;
    *)
        while true; do
            if [ -n "$PENDING_STEPS" ]; then
                log_info "[N] Apply new/missing only: steps $PENDING_STEPS (default)"
                DEFAULT_CHOICE=N
            else
                log_info "Everything is set up."
                DEFAULT_CHOICE=Q
            fi
            log_info "[A] Run all steps"
            log_info "[C] Choose steps to run"
            log_info "[X] Set steps never to run on this machine${NEVER_STEPS:+ (now: $NEVER_STEPS)}"
            log_info "[Q] Quit"
            read -p "Choice [$DEFAULT_CHOICE]: " -n 1 -r
            echo
            CHOICE="${REPLY:-$DEFAULT_CHOICE}"
            case "$CHOICE" in
                [Nn])
                    if [ -z "$PENDING_STEPS" ]; then
                        log_info "Nothing new to apply."
                        exit 0
                    fi
                    RUN_STEPS="$PENDING_STEPS"
                    break
                    ;;
                [Aa])
                    RUN_STEPS=$(all_steps_except_never)
                    break
                    ;;
                [Cc])
                    read -p "Steps to run (comma-separated, e.g. 6,12): " CHOSEN
                    if [ -n "$CHOSEN" ] && valid_step_list "$CHOSEN"; then
                        RUN_STEPS=$(echo "$CHOSEN" | tr -d ' ')
                        break
                    fi
                    log_warn "Enter step numbers between 1 and $STEP_COUNT, separated by commas"
                    ;;
                [Xx])
                    read -p "Steps never to run here (comma-separated, empty to clear): " CHOSEN
                    if [ -z "$CHOSEN" ] || valid_step_list "$CHOSEN"; then
                        NEVER_STEPS=$(echo "$CHOSEN" | tr -d ' ')
                        save_never_steps
                        refresh_status
                        print_status
                    else
                        log_warn "Enter step numbers between 1 and $STEP_COUNT, separated by commas"
                    fi
                    ;;
                [Qq])
                    exit 0
                    ;;
                *)
                    log_warn "Unknown choice: $CHOICE"
                    ;;
            esac
        done
        ;;
esac

if [ -z "$RUN_STEPS" ]; then
    log_info "Nothing to do: every step is set up or excluded in $CONFIG_FILE."
    exit 0
fi

# Helper function to check if a step should be skipped
should_skip_step() {
    ! in_list "$1" "$RUN_STEPS"
}

log_skip() {
    echo -e "${GRAY}[SKIP]${NC} Step $1: ${STEP_NAMES[$1]} (${STEP_STATE[$1]})"
}

log_info ""
log_info "Running steps: $RUN_STEPS"
log_info ""

# Step 1: Install Xcode Command Line Tools
if should_skip_step 1; then
    log_skip 1
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
    log_skip 2
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
    log_skip 3
else
    log_info "Step 3: Installing development tools and utilities..."
    # shellcheck disable=SC2086 # word-split the package list on purpose
    brew install $DEV_TOOLS
fi

# Step 4: Configure Git
if should_skip_step 4; then
    log_skip 4
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
    log_skip 5
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
    log_skip 6
else
    log_info "Step 6: Installing fzf, ripgrep, bat, fd, eza, and glow..."
    # shellcheck disable=SC2086
    brew install $CLI_TOOLS

    # Install fzf key bindings and completion
    log_info "Installing fzf key bindings..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
fi

# Step 7: Install Go
if should_skip_step 7; then
    log_skip 7
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
    log_skip 8
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
        # Homebrew's rustup (formerly rustup-init) is keg-only: it isn't linked
        # into the brew prefix, so put its bin (rustup plus the rustc/cargo
        # proxies) on PATH and install the stable toolchain through it
        brew install rustup
        RUSTUP_BIN="$(brew --prefix rustup)/bin"
        export PATH="$RUSTUP_BIN:$HOME/.cargo/bin:$PATH"
        rustup default stable

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
    log_skip 9
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
    log_skip 10
else
    log_info "Step 10: Setting up tmux configuration..."
    TMUX_CONF_PATH="$HOME/.tmux.conf"

    if [ -f "$TMUX_CONF_PATH" ]; then
        sync_config "tmux.conf" "$TMUX_CONF_PATH"
    else
        read -p "Do you want to use the provided tmux.conf? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sync_config "tmux.conf" "$TMUX_CONF_PATH"
        else
            log_info "Skipping tmux configuration"
            read -p "Stop offering the provided tmux.conf on future runs? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                add_never 10
            fi
        fi
    fi
fi

# Step 11: Install Starship and Zsh plugins
if should_skip_step 11; then
    log_skip 11
else
    log_info "Step 11: Installing Starship prompt and zsh plugins..."
    # shellcheck disable=SC2086
    brew install $STARSHIP_PKGS

    # Write starship config
    STARSHIP_CONFIG_DIR="$HOME/.config"
    STARSHIP_CONFIG_PATH="$STARSHIP_CONFIG_DIR/starship.toml"
    mkdir -p "$STARSHIP_CONFIG_DIR"

    sync_config "starship.toml" "$STARSHIP_CONFIG_PATH"
fi

# Step 12: Create/update .zshrc
if should_skip_step 12; then
    log_skip 12
else
    log_info "Step 12: Configuring .zshrc..."

    # Determine Homebrew prefix
    if [ -f "/opt/homebrew/bin/brew" ]; then
        BREW_PREFIX="/opt/homebrew"
    else
        BREW_PREFIX="/usr/local"
    fi

    ZSHRC_NEW=$(mktemp)
    cat > "$ZSHRC_NEW" << EOF
$ZSHRC_MARKER v$ZSHRC_VERSION
# Written by https://github.com/marcoshack/install and replaced (after showing
# a diff) when a newer version is applied. Put your own additions in
# ~/.zshrc.local, which is sourced at the end and never touched.

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

# Rust: Homebrew's rustup is keg-only (not linked, so it can't clash with other
# Rust installs); its bin holds the rustc/cargo proxies. ~/.cargo/bin holds
# tools from \`cargo install\`.
export PATH="${BREW_PREFIX}/opt/rustup/bin:\$HOME/.cargo/bin:\$PATH"

# Local bin (Python uv etc.)
export PATH="\$HOME/.local/bin:\$PATH"

# Editor
export EDITOR='vim'
export VISUAL='vim'

# Shared aliases (bash + zsh), installed from config/aliases
[ -f ~/.config/shell/aliases ] && source ~/.config/shell/aliases
alias find='fd'

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Local additions (kept across re-runs of the install script)
[ -f "\$HOME/.zshrc.local" ] && source "\$HOME/.zshrc.local"
EOF

    if [ ! -f "$HOME/.zshrc" ]; then
        mv "$ZSHRC_NEW" "$HOME/.zshrc"
        log_info "✓ Wrote ~/.zshrc"
    elif cmp -s "$ZSHRC_NEW" "$HOME/.zshrc"; then
        rm -f "$ZSHRC_NEW"
        log_info "✓ ~/.zshrc is already up to date"
    else
        log_info "Changes to ~/.zshrc (- current, + new):"
        diff -u "$HOME/.zshrc" "$ZSHRC_NEW" | tail -n +3 || true
        log_warn "Lines marked - are lost unless you move them to ~/.zshrc.local first"
        read -p "Replace ~/.zshrc with the new version? A backup is kept. (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ZSHRC_BACKUP="$HOME/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
            cp "$HOME/.zshrc" "$ZSHRC_BACKUP"
            mv "$ZSHRC_NEW" "$HOME/.zshrc"
            log_info "✓ Replaced ~/.zshrc (backup: $ZSHRC_BACKUP)"
        else
            rm -f "$ZSHRC_NEW"
            log_info "Kept the existing ~/.zshrc. To stop being offered this, add 12 with [X] in the menu"
        fi
    fi

    # Shared aliases: both ~/.zshrc (above) and ~/.bashrc source this file
    sync_config "aliases" "$HOME/.config/shell/aliases"
    if ! grep -qxF "$ALIASES_HOOK" "$HOME/.bashrc" 2>/dev/null; then
        printf '\n# Shared aliases (marcoshack/install)\n%s\n' "$ALIASES_HOOK" >> "$HOME/.bashrc"
        log_info "✓ ~/.bashrc now sources ~/.config/shell/aliases"
    fi
fi

# macOS doesn't need shell change step since zsh is default

# Step 13: Configure Neovim with nvim-tree
if should_skip_step 13; then
    log_skip 13
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

    # Install the config, or offer the repo version (with a diff) when it changed.
    # The lockfile pins plugins to reviewed commits.
    sync_config "nvim/init.lua" "$NVIM_CONFIG_DIR/init.lua"
    sync_config "nvim/lazy-lock.json" "$NVIM_CONFIG_DIR/lazy-lock.json"

    # Install any plugins the config declares but that aren't installed yet. Runs on
    # every invocation (not just fresh installs) so re-running the script picks up
    # newly-added plugins. `+Lazy! restore` clones missing plugins and checks out the
    # lockfile commit; plugins already at the pinned commit are left untouched.
    log_info "Installing Neovim plugins via lazy.nvim (this may take a moment)..."
    if [ -f "$NVIM_CONFIG_DIR/lazy-lock.json" ]; then
        nvim --headless "+Lazy! restore" +qa
    else
        nvim --headless "+Lazy! sync" +qa
    fi
    log_info "✓ Neovim configured with nvim-tree (toggle the file explorer with <leader>e)"
fi

# Step 14: Install herdr (agent multiplexer) and its config
if should_skip_step 14; then
    log_skip 14
else
    log_info "Step 14: Setting up herdr..."

    if command -v herdr >/dev/null 2>&1; then
        log_info "herdr is already installed"
    else
        log_info "Installing herdr via Homebrew..."
        brew install herdr
    fi

    HERDR_CONF_DIR="$HOME/.config/herdr"
    HERDR_CONF_PATH="$HERDR_CONF_DIR/config.toml"
    mkdir -p "$HERDR_CONF_DIR"

    # herdr adds `onboarding = ...` on first launch; ignore it when comparing
    sync_config "herdr/config.toml" "$HERDR_CONF_PATH" "$HERDR_CONF_IGNORE"
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
command -v eza >/dev/null 2>&1 && log_info "✓ eza installed" || log_error "✗ eza installation failed"
command -v glow >/dev/null 2>&1 && log_info "✓ glow installed" || log_error "✗ glow installation failed"
command -v tmux >/dev/null 2>&1 && log_info "✓ tmux installed" || log_error "✗ tmux installation failed"
command -v starship >/dev/null 2>&1 && log_info "✓ Starship: $(starship --version | head -1)" || log_error "✗ Starship installation failed"
command -v nvim >/dev/null 2>&1 && log_info "✓ Neovim: $(nvim --version | head -1 | awk '{print $2}')" || log_error "✗ Neovim installation failed"
command -v herdr >/dev/null 2>&1 && log_info "✓ herdr: $(herdr --version | awk '{print $2}')" || log_error "✗ herdr installation failed"

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
log_info "  - eza (ls with colours and icons; ll, la, lt aliases)"
log_info "  - glow (markdown reader)"
log_info "  - tmux (terminal multiplexer)"
log_info "  - Neovim with nvim-tree (managed by lazy.nvim, toggle with <leader>e)"
log_info "  - herdr (agent multiplexer)"
log_info ""
log_info "Git configuration:"
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Not configured")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not configured")
log_info "  - Name: $FINAL_GIT_NAME"
log_info "  - Email: $FINAL_GIT_EMAIL"
log_info ""
log_info "Happy coding!"
