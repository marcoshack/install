---
type: Design Decision
title: Step status detection on re-runs
description: Why macos.sh checks each step against the machine and applies only what is new, instead of asking which steps to skip.
tags: [scripts, re-run, config, macos]
status: draft
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-15T09:06:13Z }
---

# Step status detection on re-runs

Implemented in [`macos.sh`](../../macos.sh) (the step catalogue, `check_step`, `sync_config` and the run menu near the top). The Linux and Windows scripts still use the older skip list until they are ported.

## Problem

Re-running a script meant choosing steps to skip with no view of what was already set up. The saved skip list in `~/.install.conf` recorded a past choice, not the state of the machine, so it went stale as soon as a tool or config was added to the script. Shipped configs were never updated once they existed, so repo changes (a new herdr setting, a new alias) never reached configured machines.

## Decision

- **Detect, then default to new only.** Every step has a cheap check (`command -v`, `brew list`, a file, a line in `~/.profile`) and is shown as done, partial, missing or outdated. The default action runs only the steps that are not done.
- **One package list per step.** The lists drive both `brew install` and the check, so adding a tool to a list is enough for configured machines to pick it up.
- **Generated files carry a version.** The `.zshrc` heredoc is stamped with `ZSHRC_VERSION`, bumped whenever the template changes. Machine-specific additions live in `~/.zshrc.local`, which the generated file sources, so replacing it loses nothing.
- **Shipped configs are compared with the repo, and a baseline tells repo changes from local edits.** The hash of the repo version last deployed or offered is kept in `~/.local/state/marcoshack-install/`. A config is offered again only when the repo copy changes; local edits alone never flag it. Every replacement shows a diff, asks, and keeps a backup.
- **`~/.install.conf` becomes a never-run list.** Same file and format as the old skip list, so existing files keep working, but it now means "never on this machine" rather than "skip this time".

## Alternatives rejected

- **Compare deployed configs with the repo, without a baseline.** Any local edit would show as outdated forever (herdr's local-first workflow and `:Lazy update` both edit deployed files), and a repo change could not be told apart from a local one.
- **Version markers in every shipped config.** Works for the generated `.zshrc`, but shipped configs are copied verbatim; a marker would have to be maintained by hand in each file and survive tools that rewrite them (herdr adds `onboarding = ...`, lazy.nvim rewrites `lazy-lock.json`).
- **Symlink configs into the checkout.** Rejected earlier for the dual local/remote design: a curl-piped run has no checkout to link to (see [Architecture](../architecture.md)).
- **Overwrite configs on every run.** Simple, but silently drops local edits, which is what the "keep existing config" rule was protecting.
