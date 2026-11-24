# ============================================================================
# Machine-local overrides (sourced FIRST so secrets/employer tooling, the tmux
# auto-attach opt-in, and a keyring daemon can run before anything below —
# including the tmux exec block). Not tracked by this repo; see
# .zshrc.local.example for the template.
# ============================================================================
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# ============================================================================
# Auto-attach to tmux session "main" (MUST be before Powerlevel10k instant
# prompt block so any tmux startup output happens before instant prompt is
# enabled — avoids the "Console output during zsh initialization" warning).
#
# Why `exec`:  replaces the current zsh with tmux client. No outer zsh process
#              hangs around, so no race on a 2nd shell ("duplicate session").
# Why manual: oh-my-zsh `tmux` plugin runs AFTER instant prompt is enabled and
#              has a known race that prints "duplicate session: main" when two
#              shells launch concurrently — both visible to p10k.
#
# Opt-IN: only auto-attaches when DOTFILES_TMUX_AUTOATTACH is set (done in
# ~/.zshrc.local on workstations). Servers leave it unset so an SSH login from a
# machine that already runs tmux never nests.
#
# Escape hatches (skip tmux):
#   - DOTFILES_TMUX_AUTOATTACH unset         : default off (servers)
#   - NO_TMUX=1 set                          : explicit opt-out
#   - already inside tmux ($TMUX set)        : no nesting
#   - non-interactive shell                  : scripts / pipelines
#   - TERM=dumb / screen* / tmux*            : no terminal caps or nested
#   - VS Code / Cursor / Copilot CLI shell   : keeps AI agents OUT of tmux
# ============================================================================
if command -v tmux >/dev/null 2>&1 \
   && [[ -n "$DOTFILES_TMUX_AUTOATTACH" ]] \
   && [[ $- == *i* ]] \
   && [[ -z "$TMUX" ]] \
   && [[ -z "$NO_TMUX" ]] \
   && [[ "$TERM" != "dumb" ]] \
   && [[ "$TERM" != screen* ]] \
   && [[ "$TERM" != tmux* ]] \
   && [[ "$TERM_PROGRAM" != "vscode" ]] \
   && [[ -z "$VSCODE_INJECTION" ]] \
   && [[ -z "$VSCODE_GIT_IPC_HANDLE" ]] \
   && [[ -z "$CURSOR_TRACE_ID" ]] \
   && [[ -z "$COPILOT_AGENT_SESSION_ID" ]]; then
    exec tmux new-session -A -s main
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH=$HOME/.local/bin:$HOME/bin/local:$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Shell dependencies are pinned and updated by `install.sh --update`.
zstyle ':omz:update' mode disabled

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  history-substring-search
  fzf
  vscode
  z
  virtualenv
  colored-man-pages
  copyfile
  copypath
  history
)

# Python virtualenv
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status virtualenv)

source $ZSH/oh-my-zsh.sh
unsetopt BEEP

export COPILOT_EDITOR="code --wait --reuse-window"

###################################
# Productivity                    #
###################################
alias work="cd ~/work"
alias gitk="gitk --all"
alias gitst="git st"
alias dmesg="sudo watch -n 0.1 'dmesg | tail -n $((LINES-6))'"
# Explicit --session-id: Copilot's /restart conflicts with Agency's default --new-session-id.
alias a='z rp; agency copilot --profile-only lazy --no-default-mcps --session-id "$(uuidgen)" --yolo'
# WSLENV forwards the MCP-provided extension token to Windows Node.
alias aw='z rp; WSLENV="${WSLENV:+${WSLENV}:}PLAYWRIGHT_MCP_EXTENSION_TOKEN" agency copilot --profile lazy --no-default-mcps --session-id "$(uuidgen)" --yolo'

###################################
# NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

[ -r /etc/zsh_command_not_found ] && source /etc/zsh_command_not_found

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
