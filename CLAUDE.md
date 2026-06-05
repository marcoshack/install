# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains automated setup scripts for Linux distributions and Windows PowerShell. The scripts are designed to be executed via one-line commands to set up fresh installations:

**Linux distributions**: Complete development environment with Go, Rust, Git, zsh, and essential CLI tools.

**Windows PowerShell**: Beautiful shell customization with Starship, fuzzy finder, enhanced history, and Git aliases. Focuses on shell experience rather than development tools (which are typically done in WSL).

**Critical Design Constraint**: All functionality must be self-contained within a single file per platform:
- Linux: `.sh` files executed via `sh -c "$(curl -fsSL <url>)"`
- Windows: `.ps1` file executed via `irm <url> | iex`

Each script must be completely standalone.

## Script Architecture

### Linux Scripts Structure

All Linux distribution scripts follow this standardized flow:

1. **Logging Functions**: Colored output helpers (log_info, log_warn, log_error)
2. **Root Check**: Prevent running as root, will prompt for sudo when needed
3. **System Update**: Update package manager and upgrade packages
4. **Development Tools**: Install compiler toolchains and basic utilities (gcc, make, git, curl, vim, etc.)
5. **Git Configuration**:
   - Force HTTPS for GitHub (SSH key not yet available)
   - Prompt for username/email with existing config detection
6. **SSH Key Generation**: Create Ed25519 key for GitHub with smart email detection
7. **CLI Tools**: Install zsh, fzf, ripgrep, bat, fd
8. **Programming Languages**: Install Go and Rust (methods vary by distro)
9. **Starship + Plugins Setup**: Install Starship via package manager (or upstream installer on Ubuntu), plus `zsh-autosuggestions` and `zsh-syntax-highlighting` from the OS package manager, and write `~/.config/starship.toml`
10. **Zsh Configuration**: Write complete .zshrc with plugins, aliases, and environment
11. **Default Shell**: Change to zsh
12. **Neovim Setup**: Install Neovim and write `~/.config/nvim/` with nvim-tree + Telescope, managed by lazy.nvim
13. **Verification**: Check all installations succeeded
14. **Summary Display**: Show SSH key, git config, next steps

### Linux Distribution-Specific Differences

**Fedora ([fedora.sh](fedora.sh))**:
- Package manager: `dnf`
- Go installation: Via `dnf install golang`
- Rust installation: Via `dnf install rust cargo`
- Bat command: Works as `bat` directly
- Fd command: Installed via `fd-find`, works as `fd` directly

**Ubuntu ([ubuntu.sh](ubuntu.sh))**:
- Package manager: `apt`
- Go installation: Downloads latest from go.dev, extracts to `/usr/local/go`
  - Auto-detects architecture (amd64, arm64, armv6l)
  - Fetches version dynamically from https://go.dev/VERSION?m=text
- Rust installation: Via rustup using `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y`
  - Non-interactive installation with `-y` flag
  - Sources `~/.cargo/env` for current session
- Bat command: Installed as `batcat`, creates symlink to `bat` in `~/.local/bin`
- Fd command: Installed via `fd-find` as `fdfind`, creates symlink to `fd` in `~/.local/bin`

### Neovim Setup (all Unix scripts)

The Neovim **config** is shared and platform-independent: [config/nvim/init.lua](config/nvim/init.lua) (lazy.nvim bootstrap + plugin specs for `nvim-tree/nvim-tree.lua`, `nvim-telescope/telescope.nvim` fuzzy finder, `lewis6991/gitsigns.nvim` in-file git change signs, and `sindrets/diffview.nvim` repo-wide git diff UI) and [config/nvim/lazy-lock.json](config/nvim/lazy-lock.json) (commit-pinned lockfile, committed to the repo). Both are deployed to `~/.config/nvim/` via `fetch_config`. The plugin install step runs `nvim --headless "+Lazy! restore" +qa` to honor the lockfile (falling back to `+Lazy! sync` if no lockfile is present), and it runs on **every** invocation — not just fresh installs — so re-running the script installs any plugins the deployed config declares but that aren't installed yet. Existing `~/.config/nvim/init.lua` is preserved (warn + skip): the config files are only fetched on a fresh install, so re-runs never overwrite local edits, and newly-added plugins are only picked up once the deployed `init.lua` actually declares them (i.e. on a fresh machine, or after manually syncing the config).

Only the Neovim **install command** differs per platform:
- **macOS**: `brew install neovim`
- **Fedora**: `sudo dnf install -y neovim` (ships a current Neovim)
- **Ubuntu**: apt's Neovim is too old on LTS releases for lazy.nvim/nvim-tree, so it downloads the official `stable` release tarball (`nvim-linux-<arch>.tar.gz`, arch auto-detected like the Go step), extracts to `/opt`, and symlinks `/usr/local/bin/nvim`

**Security note**: plugins are unsandboxed Lua. The setup only uses official repos (`nvim-tree/nvim-tree.lua` + `nvim-tree/nvim-web-devicons`, `nvim-telescope/telescope.nvim` + `nvim-lua/plenary.nvim`, `lewis6991/gitsigns.nvim`, `sindrets/diffview.nvim`) and pins commits via the committed `lazy-lock.json`. Upgrades are explicit (`:Lazy update`), never automatic.

### Windows PowerShell Script Structure

The Windows script ([windows.ps1](windows.ps1)) focuses on shell customization rather than development tools (as development is done in WSL):

1. **Administrative Check**: Requires running as administrator
2. **Helper Functions**: Colored output helpers (Write-Info, Write-Warn, Write-Err)
3. **Winget Verification**: Ensures winget is available for package management
4. **Starship Installation**: Installs or upgrades Starship via winget (`Starship.Starship`)
5. **Nerd Font Installation**: Downloads and installs FiraCode Nerd Font from the Nerd Fonts GitHub release
6. **PowerShell Modules**: Installs Terminal-Icons, PSReadLine, and PSFzf
7. **Command-line Tools**: Installs fzf via winget
8. **Profile Configuration**: Creates PowerShell profile with:
   - Starship initialization (`Invoke-Expression (&starship init powershell)`)
   - Terminal-Icons import
   - PSFzf configuration (Ctrl+T for file finder, Ctrl+R for history search)
   - PSReadLine configuration (history search, predictions, key bindings, 100k history)
   - Git aliases (matching the user's existing aliases)
   - Utility aliases (ll, .., ..., wsl-here)
9. **Starship Config**: Writes `~/.config/starship.toml` matching the user's minimal config (no newline, single line, `$` character)
10. **Windows Terminal Configuration**: Automatically sets Nerd Font in Windows Terminal if installed
11. **Verification**: Checks all installations succeeded
12. **Summary Display**: Shows next steps, available aliases, and PSFzf key bindings

**Key Design Principles**:
- No user prompts (fully automated with `--silent`, `--accept-source-agreements`, `-Force` flags)
- Uses winget for package management where possible
- Preserves user's existing Git aliases from their configuration
- Uses Starship as the prompt engine with a shared cross-platform config (`~/.config/starship.toml`)
- Configures PSReadLine for enhanced command-line experience

## Key Implementation Details

### Windows PowerShell Specifics

**Non-Interactive Installation**:
- All winget commands use `--silent --accept-source-agreements --accept-package-agreements`
- All PowerShell module installations use `-Force -Scope CurrentUser`
- No confirmation prompts for file overwrites

**Profile and Prompt Management**:
- PowerShell profile: `$PROFILE` (typically `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
- Starship config: `~/.config/starship.toml` (same path used on macOS/Linux)
- Profile includes Starship init, PSFzf, PSReadLine (100k history), and Terminal-Icons

**Git Aliases**:
The script creates PowerShell functions that mirror the user's existing Git workflow:
- Uses `git.exe` explicitly to avoid potential aliases
- Preserves exact behavior from existing `aliases.ps1`
- Includes `gdiffdump` function that generates timestamped diff files

**Font Configuration**:
- Downloads FiraCode Nerd Font from the Nerd Fonts GitHub release and installs into `%WINDIR%\Fonts`
- Automatically configures Windows Terminal to use "FiraCode Nerd Font"
- Provides manual configuration instructions if automatic setup fails

**PSFzf Integration**:
- Installs both fzf (command-line tool) and PSFzf (PowerShell module)
- Configures Ctrl+T for fuzzy file/folder finding
- Configures Ctrl+R for fuzzy history search
- Enables fuzzy edit and fuzzy history aliases
- Matches user's existing PSFzf configuration

### Git HTTPS-First Strategy (Linux Only)

Linux scripts configure git to use HTTPS instead of SSH at the start:
```bash
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://
```

This is required because:
- Starship's upstream installer and some plugins may need GitHub access
- SSH key hasn't been uploaded to GitHub yet
- User instructions include how to reverse this after uploading SSH key

### Safe Prompts Pattern

Scripts check for existing configurations and prompt before overwriting:
- Git username/email
- SSH keys

For `~/.config/starship.toml` (all platforms), scripts skip writing if the file already exists and log a warning. No prompt — the existing config is preserved as-is. Otherwise the file is sourced via the `fetch_config` helper (see below; same pattern as `config/tmux.conf` and `config/nvim/`).

### Config File Sourcing (local vs remote)

Each Unix script (`macos.sh`, `fedora.sh`, `ubuntu.sh`) defines a `fetch_config <relative-path> <dest>` helper near the top, plus a source-detection block. The same script works whether run from a local checkout or piped from `curl`:

- **Local** (`./macos.sh` from a checkout): `SCRIPT_DIR` resolves to the repo and `config/starship.toml` exists there, so `LOCAL_CONFIG_DIR` is set and files are **copied** from `./config/`.
- **Remote** (`sh -c "$(curl … macos.sh)"`): `$0` is `sh`, so the local-config check fails and `fetch_config` **downloads** from `$RAW_BASE_URL/config/<path>`.

When adding a new shipped config file, place it under `config/` and fetch it with `fetch_config "<subpath>" "<dest>"` rather than a hardcoded `curl`. The model is **copy + manual sync**: there are no symlinks, so after editing a config on a machine (e.g. running `:Lazy update`, which rewrites `~/.config/nvim/lazy-lock.json`) you must copy the changed file back into the repo to commit it.

Pattern used throughout:
```bash
if [ existing_config_detected ]; then
    log_warn "Already configured"
    read -p "Do you want to reconfigure? (y/N): " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        SKIP_OPERATION=true
    fi
fi
```

### SSH Key Email Detection

Smart cascade for SSH key email:
1. Use `$GIT_EMAIL` if set during this session
2. Fall back to `git config --global user.email`
3. Prompt user if neither available

### Path Configuration

Go and Rust environments must be added to both:
- `~/.profile`: For system-level PATH (source for new sessions)
- `~/.zshrc`: For immediate zsh usage

Rust specifically:
- Fedora: Manual `CARGO_HOME` and PATH configuration
- Ubuntu: Sources `~/.cargo/env` which is created by rustup installer

## Testing Commands

When modifying scripts, test with these scenarios:

### Linux Scripts
1. **Fresh installation**: Run script on clean system
2. **Re-run**: Run script again on already-configured system (should handle gracefully)
3. **Partial config**: Test with existing git config but no SSH key
4. **Verification**: After completion, verify:
   ```bash
   go version
   rustc --version
   cargo --version
   zsh --version
   fzf --version
   rg --version
   bat --version
   ```

### Windows Script
1. **Fresh installation**: Run script on clean Windows system (as Administrator)
2. **Re-run**: Run script again on already-configured system (should upgrade/update)
3. **Verification**: After completion, verify in a new PowerShell session:
   ```powershell
   starship --version
   fzf --version
   Get-Module -ListAvailable Terminal-Icons
   Get-Module -ListAvailable PSReadLine
   Get-Module -ListAvailable PSFzf
   Test-Path $PROFILE
   Test-Path "$env:USERPROFILE\.config\starship.toml"
   # Test that prompt is themed and Git aliases work
   gst  # Should run git status
   # Test PSFzf keybindings
   # Press Ctrl+T to fuzzy find files
   # Press Ctrl+R to search history
   ```

## Repository URL Structure

Scripts are hosted on GitHub and accessed via raw URLs:

**Linux**:
```
https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/{distro}.sh
```

**Windows**:
```
https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/windows.ps1
```

When creating new distribution scripts, use these URL patterns in README.md.
