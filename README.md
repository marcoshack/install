# Installation Scripts

Automated setup scripts for Linux distributions and Windows PowerShell with development tools, modern shells, and essential utilities.

## Table of Contents

- [macOS](#macos)
  - [macOS Setup](#macos-setup)
- [Linux Distributions](#linux-distributions)
  - [Fedora Workstation Setup](#fedora-workstation-setup)
  - [Ubuntu Setup](#ubuntu-setup)
- [Windows PowerShell](#windows-powershell)
  - [PowerShell Setup](#powershell-setup)
- [Features](#features)
- [What Gets Configured](#what-gets-configured)
- [Requirements](#requirements)
- [Post-Installation](#post-installation)

## macOS

### macOS Setup

Run this command to set up a fresh macOS installation with development tools:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/macos.sh)"
```

**Installs:**
- Xcode Command Line Tools
- Homebrew package manager
- Development tools (git, vim, htop, GNU utilities)
- Programming languages (Go via Homebrew, Rust via rustup, Python via uv)
- Modern shell (zsh with Oh My Zsh - zsh is default on macOS)
- CLI tools (fzf, ripgrep, bat, fd, tmux)
- Git configuration and SSH key generation (with Keychain integration)

## Linux Distributions

### Fedora Workstation Setup

Run this command to set up a fresh Fedora installation with development tools (Go, Rust, Git, zsh, etc.):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/fedora.sh)"
```

**Installs:**
- Development tools (gcc, make, build essentials)
- Programming languages (Go, Rust)
- Modern shell (zsh with Oh My Zsh)
- CLI tools (fzf, ripgrep, bat, tmux)
- Git configuration and SSH key generation

### Ubuntu Setup

Run this command to set up a fresh Ubuntu installation with development tools:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/ubuntu.sh)"
```

**Installs:**
- Development tools (build-essential, gcc, g++)
- Programming languages (Go from official binaries, Rust via rustup)
- Modern shell (zsh with Oh My Zsh)
- CLI tools (fzf, ripgrep, bat, tmux)
- Git configuration and SSH key generation

## Windows PowerShell

### PowerShell Setup

Run this command in PowerShell **as Administrator** to set up a beautiful, functional shell environment:

```powershell
irm https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/windows.ps1 | iex
```

**Installs:**
- Oh My Posh (prompt theme engine)
- CascadiaCode Nerd Font (for icons and glyphs)
- Terminal-Icons (colorful file/folder icons)
- PSReadLine (enhanced command-line editing with 100k history)
- PSFzf + fzf (fuzzy finder with Ctrl+T and Ctrl+R)
- Git aliases and utility functions
- Automatic Windows Terminal font configuration

**Note:** This script focuses on shell customization rather than development tools, as development is typically done in WSL on Windows.

## Features

### macOS Script
- ✅ Full development environment setup via Homebrew
- ✅ Git configuration with SSH key generation (Keychain integration)
- ✅ Oh My Zsh with plugins and themes
- ✅ Essential CLI tools for productivity
- ✅ Idempotent (safe to re-run)
- ✅ Interactive prompts for configuration choices

### Linux Scripts
- ✅ Full development environment setup
- ✅ Git configuration with SSH key generation
- ✅ Modern shell (zsh) with plugins and themes
- ✅ Essential CLI tools for productivity
- ✅ Idempotent (safe to re-run)
- ✅ Interactive prompts for configuration choices

### Windows Script
- ✅ Beautiful PowerShell prompt with Oh My Posh
- ✅ Fuzzy finder integration (PSFzf)
- ✅ Enhanced history and autocomplete
- ✅ Git aliases for common workflows
- ✅ Automatic Nerd Font installation and configuration
- ✅ Fully automated (no prompts)
- ✅ Idempotent (safe to re-run)

## What Gets Configured

### macOS
- **Package Manager**: Homebrew installed and configured
- **Development Tools**: Xcode Command Line Tools, GNU utilities
- **Programming Languages**: Go (Homebrew), Rust (rustup), Python (uv)
- **Shell**: zsh with Oh My Zsh, autosuggestions, and syntax highlighting
- **Git**: Global configuration with username, email, and SSH keys (Keychain integration)
- **CLI Tools**: Modern alternatives (bat, ripgrep, fd, fzf, tmux)

### Linux (Fedora & Ubuntu)
- **Development Tools**: Complete toolchain for C/C++, Go, and Rust
- **Shell**: zsh with Oh My Zsh, autosuggestions, and syntax highlighting
- **Git**: Global configuration with username, email, and SSH keys
- **CLI Tools**: Modern alternatives (bat for cat, ripgrep for grep, fzf for fuzzy finding)
- **Terminal Multiplexer**: tmux with custom configuration

### Windows (PowerShell)
- **Prompt**: Oh My Posh with custom theme (path, git status, dotnet version)
- **Modules**: Terminal-Icons, PSReadLine, PSFzf
- **Key Bindings**:
  - Ctrl+T: Fuzzy find files/folders
  - Ctrl+R: Fuzzy search command history
  - Arrow keys: History search
- **Git Aliases**: gst, glo, gd, gpr, gb, gba, gch, gdiffdump
- **Profile**: Automatic creation in `$PROFILE` with all configurations

## Requirements

### macOS
- macOS 10.15 (Catalina) or later
- Internet connection
- Admin privileges (will prompt when needed)

### Linux
- Fresh Fedora or Ubuntu installation
- Internet connection
- sudo privileges (will prompt when needed)

### Windows
- Windows 10/11
- PowerShell 5.1 or PowerShell 7+
- Administrator privileges
- winget (App Installer from Microsoft Store)
- Windows Terminal recommended

## Post-Installation

### macOS
After running the script:
1. Run `source ~/.zshrc` or start a new terminal session
2. Add your SSH key to GitHub: https://github.com/settings/keys (use `pbcopy < ~/.ssh/id_ed25519.pub` to copy)
3. Verify installations with version commands (`go version`, `rustc --version`, `uv --version`)

### Linux
After running the script:
1. Log out and log back in (or reboot) for shell changes to take effect
2. Add your SSH key to GitHub: https://github.com/settings/keys
3. Verify installations with version commands

### Windows
After running the script:
1. Close and reopen PowerShell/Windows Terminal
2. If fonts don't look right, manually set Windows Terminal to use "CaskaydiaCove Nerd Font"
3. Try the fuzzy finder: Press Ctrl+T or Ctrl+R
4. Test Git aliases: Run `gst` to see git status

