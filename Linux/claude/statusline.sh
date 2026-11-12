#!/usr/bin/env bash
# Claude Code status line, single right-aligned line, modeled on the Copilot CLI footer:
#   model·effort │ dir │ branch* PR │ ctx bar % │ +add -del │ session % │ week %
# Reads the session JSON on stdin. Every field is optional and hidden when absent.
# Uses only normal-weight bright colors: faint text is unreadable on translucent terminals.

input=$(cat)
j() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

R=$'\e[0m'; B=$'\e[1m'
RED=$'\e[91m'; GRN=$'\e[92m'; YEL=$'\e[93m'; BLU=$'\e[94m'; MAG=$'\e[95m'; CYN=$'\e[96m'
SEP=" │ "

pct_color() {
    if   (( $1 >= 85 )); then printf '%s' "$RED"
    elif (( $1 >= 60 )); then printf '%s' "$YEL"
    else printf '%s' "$GRN"; fi
}

bar() { # 8 cells
    local n=$(( ($1 * 8 + 50) / 100 )) s="" i
    (( n > 8 )) && n=8
    for ((i = 0; i < 8; i++)); do (( i < n )) && s+="━" || s+="─"; done
    printf '%s' "$s"
}

out=()

model=$(j '.model.display_name')
effort=$(j '(.effort | strings) // .effort.level')
agent=$(j '.agent.name')
m="${B}${MAG}${model:-claude}${R}"
[ -n "$effort" ] && m+="${MAG}·${effort}${R}"
[ -n "$agent" ] && m+=" ${CYN}@${agent}${R}"
out+=("$m")

cwd=$(j '.workspace.current_dir // .cwd'); cwd=${cwd:-$PWD}
out+=("${BLU}${cwd/#$HOME/\~}${R}")

if branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
    g="${GRN}⎇ ${branch}${R}"
    [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain -uno 2>/dev/null | head -1)" ] && g+="${YEL}*${R}"

    if command -v gh >/dev/null; then
        top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
        cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/pr-$(printf '%s' "$top:$branch" | md5sum | cut -c1-16)"
        if [ ! -f "$cache" ] || (( $(date +%s) - $(stat -c %Y "$cache") > 300 )); then
            mkdir -p "${cache%/*}"
            (cd "$top" && timeout 3 gh pr view --json number -q '"#\(.number)"' 2>/dev/null) > "$cache.tmp"
            mv -f "$cache.tmp" "$cache"
        fi
        pr=$(cat "$cache" 2>/dev/null)
        [ -n "$pr" ] && g+=" ${CYN}${pr}${R}"
    fi
    out+=("$g")
fi

ctx=$(j '.context_window.used_percentage')
if [ -z "$ctx" ]; then
    used=$(j '.context_window.current_usage | if . then (.input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) else empty end')
    size=$(j '.context_window.context_window_size')
    [ -n "$used" ] && [ -n "$size" ] && (( size > 0 )) && ctx=$(( used * 100 / size ))
fi
if [ -n "$ctx" ]; then
    ctx=${ctx%.*}; c=$(pct_color "$ctx")
    out+=("${c}$(bar "$ctx") ${ctx}%${R}")
fi

add=$(j '.cost.total_lines_added'); del=$(j '.cost.total_lines_removed')
(( ${add:-0} + ${del:-0} > 0 )) && out+=("${GRN}+${add:-0}${R} ${RED}-${del:-0}${R}")

# Plan usage, named like /usage: "session" = rolling 5-hour window, "week" = 7-day window.
for win in five_hour:session seven_day:week; do
    p=$(j ".rate_limits.${win%%:*}.used_percentage")
    [ -z "$p" ] && continue
    p=${p%.*}
    out+=("${win##*:} $(pct_color "$p")${p}%${R}")
done

line=""
for p in "${out[@]}"; do line+="${line:+$SEP}$p"; done

# Right-align: pad to the terminal width. The status line runs without a tty,
# so ask tmux for the pane width first, then fall back to the controlling tty.
cols=""
[ -n "$TMUX_PANE" ] && cols=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_width}' 2>/dev/null)
[ -z "$cols" ] && cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
[ -z "$cols" ] && cols=${COLUMNS:-0}
visible=$(printf '%s' "$line" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
pad=$(( cols - visible - 6 ))   # margin for Claude Code's own status line padding
# Claude Code trims leading whitespace, so pad with U+2800 (blank braille cell),
# which renders as a space but isn't treated as whitespace.
for ((i = 0; i < pad; i++)); do printf '\u2800'; done
printf '%s\n' "$line"
