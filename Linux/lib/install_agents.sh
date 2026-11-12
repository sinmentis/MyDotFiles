#!/usr/bin/env bash
#
# install_agents.sh — deploy shared AI CLI config for whichever of
# GitHub Copilot CLI and Claude Code is installed.
#
# Single sources of truth, shared by both CLIs:
#   Shared/copilot/copilot-instructions.md   global instructions
#   Linux/copilot/mcp-config.json            MCP servers (Copilot format)
#   ~/.agents/skills, ~/.copilot/skills      skills (same SKILL.md format)
#   Linux/copilot/hooks + Linux/claude/hooks tmux @copilot_status integration
#
# Copilot reads these files directly via symlinks. Claude Code gets symlinks
# for instructions/skills/hooks, a jq-merged settings.json, and MCP servers
# registered with `claude mcp add-json` (its config format differs).
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_agents.sh

set -euo pipefail
export LOG_TAG="agents"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$(cd "$DOTFILES_LINUX_DIR/.." && pwd)"
# shellcheck source=common.sh
source "$DOTFILES_LINUX_DIR/lib/common.sh"

MCP_CONFIG="$DOTFILES_LINUX_DIR/copilot/mcp-config.json"
have() { command -v "$1" >/dev/null 2>&1 || [ -d "$HOME/.$1" ]; }

log "linking shared helper commands..."
run mkdir -p "$HOME/.local/bin"
for bin in copilot-tmux playwright-mcp amap-mcp; do
    link_dotfile "$DOTFILES_LINUX_DIR/bin/$bin" "$HOME/.local/bin/$bin"
done

# --- GitHub Copilot CLI -------------------------------------------------------
if have copilot; then
    COPILOT_DIR="$HOME/.copilot"
    run mkdir -p "$COPILOT_DIR/instructions"

    log "copilot: linking instructions, MCP config, hooks, extensions..."
    link_dotfile "$DOTFILES_ROOT/Shared/copilot/copilot-instructions.md" \
                 "$COPILOT_DIR/copilot-instructions.md"
    if [ -e "$COPILOT_DIR/mcp-config.json" ] && [ ! -L "$COPILOT_DIR/mcp-config.json" ]; then
        warn "preserving existing ~/.copilot/mcp-config.json; replace it with a symlink to $MCP_CONFIG to share MCP servers"
    else
        link_dotfile "$MCP_CONFIG" "$COPILOT_DIR/mcp-config.json"
    fi
    link_dotfile "$DOTFILES_LINUX_DIR/copilot/hooks" "$COPILOT_DIR/hooks"
    link_dotfile "$DOTFILES_LINUX_DIR/copilot/extensions/tmux-status" \
                 "$COPILOT_DIR/extensions/tmux-status"
else
    log "copilot: not installed, skipping"
fi

# --- Claude Code --------------------------------------------------------------
if have claude; then
    CLAUDE_DIR="$HOME/.claude"
    run mkdir -p "$CLAUDE_DIR/skills"

    log "claude: linking CLAUDE.md, hooks, status line..."
    link_dotfile "$DOTFILES_LINUX_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    link_dotfile "$DOTFILES_LINUX_DIR/claude/hooks" "$CLAUDE_DIR/hooks"
    link_dotfile "$DOTFILES_LINUX_DIR/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"

    log "claude: linking skills shared with Copilot..."
    for dir in "$HOME/.agents/skills"/*/ "$HOME/.copilot/skills"/*/; do
        [ -f "$dir/SKILL.md" ] || continue
        name="$(basename "$dir")"
        # Claude Code ships its own /code-review; don't shadow it.
        [ "$name" = "code-review" ] && continue
        [ -e "$CLAUDE_DIR/skills/$name" ] || run ln -s "${dir%/}" "$CLAUDE_DIR/skills/$name"
    done

    # Claude rewrites settings.json itself, so merge instead of symlinking.
    # Repo values win; permission allow-lists are unioned.
    log "claude: merging shared settings into settings.json..."
    settings="$CLAUDE_DIR/settings.json"
    [ -f "$settings" ] || run sh -c "printf '{}\n' > '$settings'"
    if ! is_dry_run; then
        tmp="$(mktemp)"
        jq --slurpfile repo "$DOTFILES_LINUX_DIR/claude/settings.json" '
            . as $local | ($local * $repo[0])
            | .permissions.allow = (($local.permissions.allow // []) + ($repo[0].permissions.allow // []) | unique)
        ' "$settings" >"$tmp" && mv "$tmp" "$settings"
    fi

    if command -v claude >/dev/null 2>&1; then
        log "claude: registering MCP servers from $MCP_CONFIG..."
        for name in $(jq -r '.mcpServers | keys[]' "$MCP_CONFIG"); do
            spec="$(jq -c --arg n "$name" '.mcpServers[$n] | del(.tools, .timeout)
                    | if .type == "local" then .type = "stdio" else . end' "$MCP_CONFIG")"
            run sh -c "claude mcp remove -s user '$name' >/dev/null 2>&1 || true"
            run claude mcp add-json -s user "$name" "$spec" >/dev/null
            log "  mcp: $name"
        done
    fi
else
    log "claude: not installed, skipping"
fi

log "done. Restart the CLIs to pick up changes."
