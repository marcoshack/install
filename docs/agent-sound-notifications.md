# Agent sound notifications over SSH (herdr, tmux, iTerm2)

Play a sound on your Mac when a coding agent (Claude Code, Kiro CLI, ...) running on a remote Linux host needs your input or finishes, without using the terminal bell.

## The problem

- The agents run on a headless remote host reached over SSH, inside [herdr](https://herdr.dev) and/or tmux.
- herdr already detects when an agent needs attention and plays a sound, but it plays it **on the remote host**. A headless host has no audio device, so nothing is heard (the herdr client log shows `no mp3-capable audio player available`).
- The terminal bell (`\a`) does reach the Mac over SSH, but it's a generic beep that sounds the same for every event.

## The approach

The remote side never plays audio. It sends an [iTerm2 custom control sequence](https://iterm2.com/documentation-escape-codes.html) (`OSC 1337 ; Custom=id=<id>:<payload> ST`). It is invisible, travels over SSH like any other terminal output, and iTerm2 hands it to a Python script, which runs `afplay` on the Mac.

```
agent needs input
  ├─ herdr (agent in a background workspace) ─► fake `pw-play` ─┐
  ├─ Claude Code hooks (outside herdr) ─────────────────────────┤
  └─ Kiro bell inside tmux ─► tmux alert-bell hook ─────────────┤
                                                                ▼
                                agent-sound <request|done>
                                  prints ESC]1337;Custom=id=agentsound:request ESC\
                                                                │  SSH
                                                                ▼
                        iTerm2 ─► AutoLaunch/agent_sound.py ─► afplay Glass.aiff
```

There are two events: `request` (the agent needs your input) and `done` (the agent finished). Each gets its own sound.

## Remote host setup

### 1. `~/.local/bin/agent-sound`

This script emits the escape sequence. Inside tmux, it wraps the sequence in tmux's DCS passthrough so tmux forwards it unchanged. Claude Code runs hooks without a controlling terminal, so `/dev/tty` isn't available there; the script then writes to the tty of the nearest parent process that has one (the agent's own terminal). The `/dev/tty` check runs in a subshell because in POSIX `sh` a failed redirection on the `:` builtin exits the whole script.

```sh
#!/bin/sh
# Ask iTerm2 (on the Mac) to play a sound: emits an iTerm2 custom control
# sequence (OSC 1337 Custom) that the AutoLaunch script agent_sound.py
# turns into `afplay`. No terminal bell involved.
#   agent-sound <request|done> [tty]
# With a tty argument, write there raw (used by the tmux alert-bell hook);
# otherwise write to our terminal, wrapped for tmux passthrough when inside tmux.
kind="${1:-request}"

# Our terminal: /dev/tty, or, when run without a controlling tty (e.g. from a
# Claude Code hook), the tty of the nearest ancestor process that has one.
term=/dev/tty
if ! ( : > /dev/tty ) 2>/dev/null; then
  term=; pid=$PPID
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$t" ] && [ "$t" != "?" ]; then term="/dev/$t"; break; fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
fi

osc=$(printf '\033]1337;Custom=id=agentsound:%s\033\\' "$kind")
if [ -n "${2:-}" ]; then
  printf '%s' "$osc" > "$2" 2>/dev/null
elif [ -z "$term" ]; then
  exit 0
elif [ -n "${TMUX:-}" ]; then
  printf '\033Ptmux;%s\033\\' "$(printf '%s' "$osc" | sed 's/\x1b/\x1b\x1b/g')" > "$term" 2>/dev/null
else
  printf '%s' "$osc" > "$term" 2>/dev/null
fi
exit 0
```

### 2. herdr: fake audio player

To play a sound, herdr tries these players in order: `paplay`, `pw-play`, `ffplay`, `mpg123`, `mpv`. A `pw-play` shim earlier in `PATH` intercepts the call. (`paplay` may exist on the host, but it can't decode mp3, so herdr falls through to the shim.) The shim runs as a child of the herdr client, so `/dev/tty` is the terminal you're attached from.

`~/.local/bin/pw-play`:

```sh
#!/bin/sh
# Shim for herdr's sound playback (herdr tries paplay, then pw-play, ...).
# This host has no audio device, so forward the event to iTerm2 on the Mac.
# herdr's config points done_path/request_path at sounds/{done,request}.mp3,
# so the file name tells us which event it is.
case "$*" in
  *done*) exec agent-sound done ;;
  *) exec agent-sound request ;;
esac
```

With the default config, herdr passes a temp file named like `/tmp/herdr-sound-<pid>-<n>.mp3`, which doesn't say which event it is. Point the two events at separate files so the shim can tell them apart. The files are never played, so their content doesn't matter:

```sh
mkdir -p ~/.config/herdr/sounds
printf x > ~/.config/herdr/sounds/request.mp3
printf x > ~/.config/herdr/sounds/done.mp3
```

`~/.config/herdr/config.toml`:

```toml
# No audio on this host: the pw-play shim in ~/.local/bin forwards these to iTerm2
# (the file names tell it which event it is).
[ui.sound]
enabled = true
done_path = "sounds/done.mp3"
request_path = "sounds/request.mp3"
```

Apply the config with `herdr server reload-config`.

herdr detects agent state itself, so this covers every agent it supports. It only plays sounds for agents in **background** workspaces.

### 3. Claude Code hooks (outside herdr)

Claude Code fires a `Notification` hook when it asks for permission or has been waiting for input. That hook doesn't fire when Claude asks you a question, so a `PreToolUse` hook on the `AskUserQuestion` tool covers that case. Inside herdr the hook does nothing, because herdr already plays the sound.

`~/.claude/hooks/agent-sound.sh`:

```sh
#!/bin/sh
# Play the "request" sound on the Mac when Claude needs attention (question, permission prompt, idle input).
# Inside herdr, herdr's own agent detection handles it (see ~/.local/bin/pw-play), so skip.
cat >/dev/null
[ "${HERDR_ENV:-}" = "1" ] && exit 0
exec "$HOME/.local/bin/agent-sound" request
```

Add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "sh ~/.claude/hooks/agent-sound.sh", "timeout": 5 }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          { "type": "command", "command": "sh ~/.claude/hooks/agent-sound.sh", "timeout": 5 }
        ]
      }
    ]
  }
}
```

### 4. Kiro CLI: ring the bell

Kiro can only signal with a bell (`bel`) or with OSC 9. Use `bel`; tmux turns it into a sound (next step):

```sh
kiro-cli settings chat.enableNotifications true
kiro-cli settings chat.notificationMethod bel
```

### 5. tmux

Add to `~/.tmux.conf`:

```tmux
# Agent sounds: let agent-sound's escape sequence through to iTerm2, and turn
# bells (e.g. from Kiro) into the iTerm2 "request" sound instead of a beep.
set -g allow-passthrough all
set -g monitor-bell on
set -g bell-action none
set -g visual-bell off
set-hook -g alert-bell 'run-shell -b "~/.local/bin/agent-sound request #{client_tty}"'
```

- `allow-passthrough` (tmux 3.3+) lets the DCS-wrapped sequence from `agent-sound` reach iTerm2. Use `all` rather than `on`: `on` only passes it through from visible panes, so an agent in a background window would stay silent.
- `bell-action none` stops tmux from forwarding the raw beep. The `alert-bell` hook still fires and writes the escape sequence straight to the client's tty.

## Mac setup (iTerm2)

1. iTerm2 → Settings → General → Magic → check **Enable Python API**.
2. Scripts menu → Manage → **Install Python Runtime**.
3. Save the script below as `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/agent_sound.py`.
4. Restart iTerm2, or run it once from Scripts → AutoLaunch → `agent_sound.py`.
5. Settings → Profiles → *your profile* → Terminal → check **Silence bell**. This mutes stray bells, for example from Kiro when it isn't inside tmux.

```python
#!/usr/bin/env python3
# iTerm2 AutoLaunch script: plays a sound when a remote agent (Claude/Kiro via
# herdr/tmux) emits  ESC ] 1337 ; Custom=id=agentsound:<request|done> ST
import subprocess

import iterm2

SOUNDS = {
    "request": "/System/Library/Sounds/Glass.aiff",  # agent needs your input
    "done": "/System/Library/Sounds/Hero.aiff",      # agent finished
}


async def main(connection):
    async with iterm2.CustomControlSequenceMonitor(
        connection, "agentsound", r"^(request|done)$"
    ) as mon:
        while True:
            match = await mon.async_get()
            subprocess.Popen(["afplay", SOUNDS[match.group(1)]])


iterm2.run_forever(main)
```

To change a sound, edit `SOUNDS` (any `.aiff`, `.mp3` or `.wav` works) and restart the script from the Scripts menu. Preview sounds with `afplay /System/Library/Sounds/Submarine.aiff`. Other built-in sounds include Ping, Pop, Purr, Funk and Tink.

## Testing

Run on the remote host:

```sh
# From inside herdr: exercises the full herdr -> shim -> iTerm2 path
herdr notification show test --sound request
herdr notification show test --sound done

# From any shell (plain SSH or tmux): tests agent-sound -> iTerm2 directly
agent-sound request

# From tmux: tests the bell -> alert-bell hook path
printf '\a'
```

## Caveats and troubleshooting

- **No sound at all:** check that the script is listed under Scripts → AutoLaunch, and look for errors in Scripts → Manage → Console.
- **herdr is silent:** check `~/.config/herdr/herdr-client.log` for `herdr::sound` warnings, and make sure `~/.local/bin` is in the herdr client's `PATH`. If a real `pw-play` gets installed ahead of the shim, rename the shim to a later player in herdr's list (for example `mpv`).
- **tmux eats the sequence:** confirm `tmux show -gw allow-passthrough` prints `all`.
- herdr only plays sounds for background workspaces, so an agent in the workspace you're looking at stays silent.
- Kiro in tmux always plays the `request` sound, because a bell can't say which event happened.
- This depends on iTerm2. Other terminals ignore `OSC 1337 Custom`.
