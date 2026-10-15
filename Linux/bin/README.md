# Linux Commands

## `copilot-tmux`

Save and restore tmux windows running GitHub Copilot CLI through their original
launcher, including `agency copilot` profile and MCP arguments.

```bash
copilot-tmux save
copilot-tmux show
copilot-tmux shutdown
copilot-tmux restore
```

Useful options:

```bash
copilot-tmux save --tmux-session NAME
copilot-tmux shutdown --dry-run
copilot-tmux shutdown --tmux-session NAME
copilot-tmux shutdown --yes
copilot-tmux restore --dry-run
copilot-tmux restore --no-attach
copilot-tmux --version
```

Output is colored when writing to a terminal. Set `NO_COLOR=1` to disable it.

The command dynamically discovers tmux panes and their process trees. It reads
the current Copilot session ID from the documented `sessionStart` hook. Live
session-state inspection remains as a fallback for sessions started before the
hook was installed.

Snapshots use each Copilot session's current working directory, including
directory changes made after launch. The pane's directory remains a fallback
when no session directory is recorded.

Snapshots are stored with owner-only permissions at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/copilot-tmux/snapshot.json
```

Current scope:

- Linux and WSL
- One Copilot session per tmux window
- GitHub Copilot CLI, including an outer `agency copilot` launcher
- Manual save, shutdown, and restore

Each `save` replaces the previous snapshot, including a filtered
`save --tmux-session NAME`. Restore after the saved tmux sessions have exited;
existing tmux session names are never overwritten. Preview recovery commands
with `restore --dry-run`.
An absent tmux server is treated as having no existing panes or sessions.
Permission and other connection errors are reported instead.

### Shutting down before stopping WSL

Run `copilot-tmux shutdown` from a separate shell. It shows the target sessions
and asks for confirmation, saves a fresh snapshot, then sends `SIGTERM` to each
Copilot main process and waits for it to exit before proceeding. Copilot handles
this signal through its normal shutdown cleanup; running work is interrupted,
not completed. Resume the saved conversations with `copilot-tmux restore` after
restarting WSL. In-memory tasks do not resume automatically.

`--dry-run` only previews targets; it neither saves nor stops anything.
`--yes` confirms interruption without a prompt. Like `save`, shutdown replaces
the previous snapshot, including when filtered with `--tmux-session NAME`.

Shutdown requires Linux pidfd support (a kernel feature that keeps a process
handle tied to the original process even if its PID is reused). Targets are
rechecked before signalling. If saving fails, nothing is stopped. If a target
changes, signalling fails, or a process takes longer than 30 seconds to exit,
shutdown stops with an error and does not force-kill it or stop later targets.
Resolve the error before stopping WSL. Normal shutdown reduces abrupt-write
risk; it is not a backup or a guarantee against storage or runtime failures.

The command does not delete conversation history or kill tmux panes, windows,
sessions, or unrelated processes. It refuses to stop the Copilot process hosting
the command itself. Shells may remain after Copilot exits; without restarting WSL,
existing tmux session names can still block `restore`.

When a Copilot pane has non-Copilot sibling panes, restore recreates the
Copilot window as a single pane. The sibling panes and their running commands
are not restored.

An interrupted build, shell command, subagent, or other in-memory process does
not resume mid-execution. The Copilot conversation and repository files remain
available.

`Linux/lib/install_tmux.sh` symlinks this command into `~/.local/bin`.

### Animated Copilot status

`Linux/lib/install_copilot.sh` installs the `tmux-status` Copilot CLI extension.
It uses session lifecycle events rather than terminal output to update tmux
window labels:

| State | Indicator |
|---|---|
| Running, including related background work | Thinking icon and a spinner updating every 200 ms |
| Waiting for permission or user input | Raised-hand icon, without animation |
| Finished but not viewed | Check mark and the existing yellow bell highlight |
| Failed but not viewed | `!` and the yellow bell highlight |
| Idle or cancelled | No indicator |

Viewing a window clears its unread indicator. A waiting indicator remains until
the request is answered. Status is tracked per pane; a window label includes
the indicators of its panes. The window index, name, and native tmux flags remain
intact. Indicators appear between `index:` and the window name. Idle windows keep
their original text without an indicator.

Tabs have one space of padding on each side and a visible ` | ` separator.
Inactive tabs have a dark-gray background, the active tab is blue, and unread
alerts retain the yellow background. The right side shows a compact date and
24-hour time, such as `10-14 09:35`. No theme plugins or special separator fonts
are required.

Animation stops while idle or waiting. Running and waiting indicators expire
after about five seconds without a heartbeat, so a killed process cannot leave a
permanent spinner. Normal shutdown removes the pane's status options.
Temporary process-spawn failures (`EAGAIN`) are reported once per outage and
retried every second. Indicators recover automatically when tmux commands can
run again; other command failures stop updates and report the error.

The extension replaces the older `tmux-alerts.json` bell hooks. It requires a
Copilot CLI version with extension support and uses the CLI's bundled SDK;
no additional Node.js packages are needed. After installation, reload tmux and
use `/restart` in existing Copilot sessions:

```bash
tmux source-file ~/.tmux.conf
```

## `playwright-mcp`

Launch `@playwright/mcp` with a persistent user profile without embedding a
machine-specific home directory in `mcp-config.json`.

Defaults:

```text
Browser:  $HOME/.local/share/playwright/chrome
Profile:  $HOME/.copilot/playwright-profile
```

If the default browser executable is absent, Playwright MCP selects its normal
browser. Override either location when needed:

```bash
export PLAYWRIGHT_MCP_EXECUTABLE_PATH=/path/to/chrome
export PLAYWRIGHT_MCP_USER_DATA_DIR=/path/to/profile
export PLAYWRIGHT_MCP_VERSION=0.0.83
```

`Linux/lib/install_copilot.sh` symlinks this command into `~/.local/bin`.
