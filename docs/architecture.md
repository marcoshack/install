---
type: Reference
title: Architecture
description: How the per-platform setup scripts and the shared config/ files fit together, and where to start reading.
tags: [architecture, scripts, config]
status: draft
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-11T03:13:51Z }
---

# Architecture

The repository sets up a fresh machine with one command per platform. Each script is fetched and run straight from GitHub (`bash -c "$(curl -fsSL …)"` or `irm … | iex`), so every script must be self-contained: one file per platform, no sourcing of sibling scripts.

## Parts

| Part | Owns |
|---|---|
| [`macos.sh`](../macos.sh), [`fedora.sh`](../fedora.sh), [`ubuntu.sh`](../ubuntu.sh), [`omarchy.sh`](../omarchy.sh) | A full development environment: toolchains, git and SSH key, CLI tools, Go/Rust, zsh + Starship, Neovim, tmux, herdr. They share the same numbered step flow and differ mainly in package manager and install method. |
| [`windows.ps1`](../windows.ps1) | Shell experience only (Starship, PSReadLine, PSFzf, Terminal-Icons, Nerd Font, git aliases); development happens in WSL. |
| [`config/`](../config/) | Platform-independent config files shipped by the scripts: `starship.toml`, `aliases`, `tmux.conf`, `nvim/` (with a committed `lazy-lock.json`) and `herdr/config.toml`. |
| [`README.md`](../README.md) | Feature table and the one-line install commands. |

## How they connect

- Each Unix script copies a file from `config/` when run from a local checkout and downloads it from the raw GitHub URL when piped from `curl`, through a `fetch_config <subpath> <dest>` helper. New shipped config goes under `config/` and is deployed the same way.
- Deployment is copy, not symlink: a config edited on a machine has to be copied back into `config/` to be committed.
- Existing user config (for example `starship.toml`, `nvim/init.lua`, herdr config) is kept rather than overwritten; the scripts are meant to be safe to re-run.
- Unix scripts re-exec themselves under bash when started from a POSIX `sh`, so that guard must stay first in each file.
- Step numbers are saved in `~/.install.conf` to let users skip steps, so new steps are appended rather than inserted.

## Where to start

Read `AGENTS.md` at the repository root for the per-platform differences and implementation rules, then the script for the platform you are changing. Git aliases in `config/aliases` are mirrored in `windows.ps1` and must be kept in sync.
