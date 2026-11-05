---
name: herdr
description: Change herdr (agent multiplexer) settings such as toasts, keybindings, theme, sidebar or UI options. Use whenever the user asks to change, tweak, test or fix herdr configuration (~/.config/herdr/config.toml or config/herdr/config.toml in this repo).
---

# Changing herdr configuration

Two copies of the herdr config exist:

- **Local**: `~/.config/herdr/config.toml`, the one the running herdr reads.
- **Repo**: `config/herdr/config.toml`, the one the install scripts deploy to new machines via `fetch_config`.

They are allowed to differ. For example, the local copy may have a different `[ui.toast] delivery` value. Never copy one file over the other wholesale. Apply only the specific change the user asked for.

## Workflow

1. **Change the local config first.** Edit only `~/.config/herdr/config.toml`. Do not touch the repo copy yet.
2. **Validate and apply it right away.** Run this after every edit to the local config:
   ```bash
   herdr config check && herdr server reload-config
   ```
   `reload-config` should print `"status":"applied"` with empty `diagnostics`. If `check` fails or diagnostics are reported, fix the config before continuing. If a setting only takes effect on restart, tell the user.
3. **Let the user try it.** Explain what changed and how to see it. For toast changes, you can trigger one with a short background command (for example `sleep 3` run in the background) so the turn ends and herdr notifies.
4. **Ask before touching the repo.** Ask whether the user is satisfied and wants the change applied to the repository and committed. Do not edit `config/herdr/config.toml` or commit until they say yes.
5. **On yes:** apply the same change to `config/herdr/config.toml`. Check whether it depends on a setting that differs between the two copies (for example, `[ui.toast.herdr] position` only applies when `delivery = "herdr"`), and mention any such dependency. Then commit with the `marcoshack:commit` skill.

## Reference

- Docs: https://herdr.dev/docs/configuration and https://herdr.dev/docs/config-reference. Check them for exact key names instead of guessing.
- `herdr --help` lists the CLI commands. `herdr --skill` explains how to control panes and agents.
