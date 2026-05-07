#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current working directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Shortened directory format: ~/currentDir
home="$HOME"
if [[ "$cwd" == "$home" ]]; then
    short_dir="~"
elif [[ "$cwd" == "$home"/* ]]; then
    short_dir="~/$(basename "$cwd")"
else
    short_dir="$(basename "$cwd")"
fi

# Get git branch
git_branch=""
if git_branch_out=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null); then
    git_branch="$git_branch_out"
fi

# Lines changed
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Battery-style bar: solid background fill, label floats inside
# $1=pct  $2=line color (for brackets + %)  $3=label  $4=bg color (ANSI bg code)
# Total inner width = 14 chars (label + fill + empty)
make_bar() {
    local pct="$1"
    local line_color="$2"
    local label="$3"
    local bg_color="$4"
    local total_width=14
    local label_len=${#label}
    local fill_avail=$(( total_width - label_len ))

    local fill_chars
    fill_chars=$(printf "%.0f" "$(echo "$pct * $fill_avail / 100" | bc -l)")
    [ "$fill_chars" -gt "$fill_avail" ] && fill_chars=$fill_avail

    local empty=$(( fill_avail - fill_chars ))

    local bar
    bar="${line_color}["
    bar+="${bg_color}"$'\033[1;97m'"${label}"$'\033[0m'"${bg_color}"
    for ((i=0; i<fill_chars; i++)); do bar+=" "; done
    bar+=$'\033[0m'
    for ((i=0; i<empty; i++)); do bar+=" "; done
    bar+="${line_color}]"$'\033[0m'

    printf '%s' "$bar"
}

# ── Line 1: dir  branch  +N -N ───────────────────────────────────────────────
printf "\033[36m%s\033[0m" "$short_dir"
[ -n "$git_branch" ] && printf "  \033[35m%s\033[0m" "$git_branch"
if [ "$lines_added" != "0" ] || [ "$lines_removed" != "0" ]; then
    [ "$lines_added"   != "0" ] && printf "  \033[32m+%s\033[0m" "$lines_added"
    [ "$lines_removed" != "0" ] && printf "  \033[31m-%s\033[0m" "$lines_removed"
fi
printf "\n"

CTX_COLOR=$'\033[36m'    # cyan fg
CTX_BG=$'\033[46m'      # cyan bg
RATE_COLOR=$'\033[35m'  # magenta fg
RATE_BG=$'\033[45m'     # magenta bg

# ── Line 2: context bar ───────────────────────────────────────────────────────
context_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$context_used" ]; then
    used_int=$(printf "%.0f" "$context_used")
    bar=$(make_bar "$context_used" "$CTX_COLOR" "ctx" "$CTX_BG")
    printf "%s  %s%3d%%\033[0m\n" "$bar" "$CTX_COLOR" "$used_int"
else
    bar=$(make_bar "0" "$CTX_COLOR" "ctx" "$CTX_BG")
    printf "%s  %s---\033[0m\n" "$bar" "$CTX_COLOR"
fi

# ── Line 3: 5h rate bar + reset time ─────────────────────────────────────────
rate_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$rate_used" ]; then
    rate_int=$(printf "%.0f" "$rate_used")
    bar=$(make_bar "$rate_used" "$RATE_COLOR" " 5h" "$RATE_BG")

    time_str=""
    if [ -n "$rate_resets_at" ]; then
        now=$(date +%s)
        remaining=$(( rate_resets_at - now ))
        if [ "$remaining" -gt 0 ]; then
            h=$(( remaining / 3600 ))
            m=$(( (remaining % 3600) / 60 ))
            if [ "$h" -gt 0 ]; then
                time_str="  ·  ${h}h ${m}m left"
            else
                time_str="  ·  ${m}m left"
            fi
        fi
    fi

    printf "%s  %s%3d%%%s\033[0m" "$bar" "$RATE_COLOR" "$rate_int" "$time_str"
else
    bar=$(make_bar "0" "$RATE_COLOR" " 5h" "$RATE_BG")
    printf "%s  %s---\033[0m" "$bar" "$RATE_COLOR"
fi
