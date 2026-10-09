# Linux Commands

## `copilot-tmux`

Save and restore tmux windows running GitHub Copilot CLI through their original
launcher, including `agency copilot` profile and MCP arguments.

```bash
copilot-tmux save
copilot-tmux show
copilot-tmux restore
```

Useful options:

```bash
copilot-tmux save --tmux-session NAME
copilot-tmux restore --dry-run
copilot-tmux restore --no-attach
```

The command dynamically discovers tmux panes and their process trees. It reads
the current Copilot session ID from the documented `sessionStart` hook. Live
session-state inspection remains as a fallback for sessions started before the
hook was installed.

Snapshots are stored with owner-only permissions at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/copilot-tmux/snapshot.json
```

Current scope:

- Linux and WSL
- One Copilot session per tmux window
- GitHub Copilot CLI, including an outer `agency copilot` launcher
- Manual save and restore

Each `save` replaces the previous snapshot, including a filtered
`save --tmux-session NAME`. Restore after the saved tmux sessions have exited;
existing tmux session names are never overwritten. Preview recovery commands
with `restore --dry-run`.

When a Copilot pane has non-Copilot sibling panes, restore recreates the
Copilot window as a single pane. The sibling panes and their running commands
are not restored.

An interrupted build, shell command, subagent, or other in-memory process does
not resume mid-execution. The Copilot conversation and repository files remain
available.

`Linux/lib/install_tmux.sh` symlinks this command into `~/.local/bin`.

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
