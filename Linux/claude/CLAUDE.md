# Claude Code user instructions

Shared with Copilot CLI (single source of truth):

@~/MyDotFiles/Shared/copilot/copilot-instructions.md

## Claude Code specifics

- The shared file above was written for Copilot CLI. Where it mentions Copilot-only features, map them to Claude Code equivalents: sub-agents are the Agent tool (leave the model on the strongest one, don't downgrade to haiku/sonnet), skills live in `~/.claude/skills`, MCP servers are configured with `claude mcp ... -s user`.
- "Rubber-duck on a different model family" isn't available here. For an independent second opinion, use a fresh sub-agent with no shared context instead.
- VM operations history (Cloudflare Tunnel, SSH/mosh, WARP, dotfiles sync model) is logged in `~/.copilot-memory.md`. Read it before touching networking, cloudflared, or shell config on this machine.
- Synced config lives in `~/MyDotFiles`. Machine-local shell settings go in `~/.zshrc.local`, never in synced files.
