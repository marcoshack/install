# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains automated setup scripts for Linux distributions. The scripts are designed to be executed via one-line curl commands to set up fresh installations with development tools, zsh, and essential utilities.

**Critical Design Constraint**: All functionality must be self-contained within a single `.sh` file per distribution. Users execute these scripts remotely via `curl -fsSL <url> | bash`, so each script must be completely standalone.

## Script Architecture

### Common Structure (Both Scripts)

All distribution scripts follow this standardized flow:

1. **Logging Functions**: Colored output helpers (log_info, log_warn, log_error)
2. **Root Check**: Prevent running as root, will prompt for sudo when needed
3. **System Update**: Update package manager and upgrade packages
4. **Development Tools**: Install compiler toolchains and basic utilities (gcc, make, git, curl, vim, etc.)
5. **Git Configuration**:
   - Force HTTPS for GitHub (SSH key not yet available)
   - Prompt for username/email with existing config detection
6. **SSH Key Generation**: Create Ed25519 key for GitHub with smart email detection
7. **CLI Tools**: Install zsh, fzf, ripgrep, bat
8. **Programming Languages**: Install Go (method varies by distro)
9. **Oh My Zsh Setup**: Install framework and plugins (zsh-autosuggestions, zsh-syntax-highlighting)
10. **Zsh Configuration**: Write complete .zshrc with plugins, aliases, and environment
11. **Default Shell**: Change to zsh
12. **Verification**: Check all installations succeeded
13. **Summary Display**: Show SSH key, git config, next steps

### Distribution-Specific Differences

**Fedora ([fedora.sh](fedora.sh))**:
- Package manager: `dnf`
- Go installation: Via `dnf install golang`
- Bat command: Works as `bat` directly

**Ubuntu ([ubuntu.sh](ubuntu.sh))**:
- Package manager: `apt`
- Go installation: Downloads latest from go.dev, extracts to `/usr/local/go`
  - Auto-detects architecture (amd64, arm64, armv6l)
  - Fetches version dynamically from https://go.dev/VERSION?m=text
- Bat command: Installed as `batcat`, creates symlink to `bat` in `~/.local/bin`

## Key Implementation Details

### Git HTTPS-First Strategy

Both scripts configure git to use HTTPS instead of SSH at the start:
```bash
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://
```

This is required because:
- Oh My Zsh and plugins are cloned from GitHub
- SSH key hasn't been uploaded to GitHub yet
- User instructions include how to reverse this after uploading SSH key

### Safe Prompts Pattern

Scripts check for existing configurations and prompt before overwriting:
- Git username/email
- SSH keys
- Oh My Zsh installation

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

Go environment must be added to both:
- `~/.profile`: For system-level PATH (source for new sessions)
- `~/.zshrc`: For immediate zsh usage

## Testing Commands

When modifying scripts, test with these scenarios:

1. **Fresh installation**: Run script on clean system
2. **Re-run**: Run script again on already-configured system (should handle gracefully)
3. **Partial config**: Test with existing git config but no SSH key
4. **Verification**: After completion, verify:
   ```bash
   go version
   zsh --version
   fzf --version
   rg --version
   bat --version
   ```

## Repository URL Structure

Scripts are hosted on GitHub and accessed via raw URLs:
```
https://raw.githubusercontent.com/marcoshack/install/refs/heads/main/{distro}.sh
```

When creating new distribution scripts, use this URL pattern in README.md.
