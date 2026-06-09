# Installation Scripts

Automated setup scripts for macOS, Linux distributions, and Windows PowerShell with development tools, modern shells, and essential utilities.

## Features

| Feature | macOS | Linux | Windows |
|---------|:-----:|:-----:|:-------:|
| Starship prompt | ✓ | ✓ | ✓ |
| fzf (fuzzy finder) | ✓ | ✓ | ✓ |
| Git configuration | ✓ | ✓ | ✓ |
| zsh with plugins (autosuggestions, syntax-highlighting) | ✓ | ✓ | |
| Go | ✓ | ✓ | |
| Rust | ✓ | ✓ | |
| ripgrep | ✓ | ✓ | |
| bat | ✓ | ✓ | |
| fd | ✓ | ✓ | |
| glow (markdown reader) | ✓ | ✓ | ✓ |
| tmux | ✓ | ✓ | |
| Neovim (nvim-tree + Telescope, managed by lazy.nvim) | ✓ | ✓ | |
| SSH key generation | ✓ | ✓ | |
| Development tools (compiler toolchains) | ✓ | ✓ | |
| Python (via uv) | ✓ | | |
| PSReadLine (enhanced editing, 100k history) | | | ✓ |
| PSFzf (Ctrl+T files, Ctrl+R history) | | | ✓ |
| Terminal-Icons | | | ✓ |
| FiraCode Nerd Font | | | ✓ |
| Windows Terminal font configuration | | | ✓ |

All scripts are idempotent (safe to re-run).

## Table of Contents

- [macOS](#macos)
- [Linux Distributions](#linux-distributions)
  - [Fedora Workstation](#fedora-workstation)
  - [Ubuntu](#ubuntu)
- [Windows PowerShell](#windows-powershell)

## macOS

Run this command to set up a fresh macOS installation:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/macos.sh)"
```

**Platform specific:**
- Xcode Command Line Tools
- Homebrew package manager
- GNU utilities (coreutils, findutils, gnu-sed, grep)
- SSH key with Keychain integration

**Requirements:**
- macOS 10.15 (Catalina) or later
- Internet connection
- Admin privileges (will prompt when needed)

**Post-installation:**
1. Run `source ~/.zshrc` or start a new terminal session
2. Add your SSH key to GitHub: https://github.com/settings/keys (use `pbcopy < ~/.ssh/id_ed25519.pub` to copy)
3. Verify installations with version commands (`go version`, `rustc --version`, `uv --version`)

## Linux Distributions

### Fedora Workstation

Run this command to set up a fresh Fedora installation:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)"
```

**Platform specific:**
- Go and Rust installed via `dnf`

**Requirements:**
- Fresh Fedora installation
- Internet connection
- sudo privileges (will prompt when needed)

**Post-installation:**
1. Log out and log back in (or reboot) for shell changes to take effect
2. Add your SSH key to GitHub: https://github.com/settings/keys
3. Verify installations with version commands

### Ubuntu

Run this command to set up a fresh Ubuntu installation:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)"
```

**Platform specific:**
- Go installed from official binaries (auto-detects architecture)
- Rust installed via rustup
- Neovim installed from official release tarball (apt version is too old on LTS)

**Requirements:**
- Fresh Ubuntu installation
- Internet connection
- sudo privileges (will prompt when needed)

**Post-installation:**
1. Log out and log back in (or reboot) for shell changes to take effect
2. Add your SSH key to GitHub: https://github.com/settings/keys
3. Verify installations with version commands

## Windows PowerShell

Run this command in PowerShell **as Administrator**:

```powershell
irm https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/windows.ps1 | iex
```

**Platform specific:**
- Fully automated (no prompts)
- Focuses on shell customization (development is typically done in WSL)
- Git aliases: gst, glo, gd, gpr, gb, gba, gch, gdiffdump
- Key bindings: Ctrl+T (fuzzy find files), Ctrl+R (fuzzy history), Arrow keys (history search)

**Requirements:**
- Windows 10/11
- PowerShell 5.1 or PowerShell 7+
- Administrator privileges
- winget (App Installer from Microsoft Store)
- Windows Terminal recommended

**Post-installation:**
1. Close and reopen PowerShell/Windows Terminal
2. If fonts don't look right, manually set Windows Terminal to use "FiraCode Nerd Font"
3. Try the fuzzy finder: Press Ctrl+T or Ctrl+R
4. Test Git aliases: Run `gst` to see git status
