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

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Paths to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH=~/bin/local:$PATH
export PATH=/usr/share/code/bin:$PATH
export PATH=$HOME/.local/bin:$PATH

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
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

export TERM=xterm-256color
set background=dark
set t_Co=256
# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

###################################
# Productivity                    #
###################################
alias zshconfig="mate ~/.zshrc"
alias ohmyzsh="mate ~/.oh-my-zsh"
alias work="cd ~/work"
alias gitk="gitk --all"
alias gitst="git st"
alias explorer="nautilus ."
alias dmesg="sudo watch -n 0.1 'dmesg | tail -n $((LINES-6))'"
alias detectMonitor="sudo service sddm restart"

###################################
# NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

[ -r /etc/zsh_command_not_found ] && source /etc/zsh_command_not_found

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Bugfix: remove first characters repeate
export LC_CTYPE=en_US.UTF-8

PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

