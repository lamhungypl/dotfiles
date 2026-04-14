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

# Extract context used percentage and create progress bar
context_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_str=""

if [ -n "$context_used" ]; then
    used_int=$(printf "%.0f" "$context_used")

    if (( $(echo "$context_used < 50" | bc -l) )); then
        bar_color=$'\033[32m'  # Green for 0-50%
    elif (( $(echo "$context_used < 75" | bc -l) )); then
        bar_color=$'\033[33m'  # Yellow for 50-75%
    else
        bar_color=$'\033[31m'  # Red for 75-100%
    fi

    bar_length=10
    total_blocks=$(echo "$context_used * $bar_length / 100" | bc -l)
    full_blocks=$(printf "%.0f" "$(echo "$total_blocks" | bc -l | awk '{print int()}')")
    fraction=$(echo "$total_blocks - $full_blocks" | bc -l)

    shade_char=""
    if (( $(echo "$fraction >= 0.875" | bc -l) )); then
        shade_char="█"
        full_blocks=$((full_blocks + 1))
    elif (( $(echo "$fraction >= 0.625" | bc -l) )); then
        shade_char="▓"
    elif (( $(echo "$fraction >= 0.375" | bc -l) )); then
        shade_char="▒"
    elif (( $(echo "$fraction >= 0.125" | bc -l) )); then
        shade_char="░"
    fi

    bar=$'\033[0m'"["
    bar+="${bar_color}"
    for ((i=0; i<full_blocks; i++)); do bar+="█"; done
    [ -n "$shade_char" ] && [ "$full_blocks" -lt "$bar_length" ] && bar+="$shade_char"
    bar+=$'\033[0m'
    current_length=$full_blocks
    [ -n "$shade_char" ] && [ "$full_blocks" -lt "$bar_length" ] && current_length=$((current_length + 1))
    empty=$((bar_length - current_length))
    for ((i=0; i<empty; i++)); do bar+=" "; done
    bar+="]"

    context_str=" $bar ${used_int}%"
fi

# Extract 5-hour rate limit data
rate_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rate_str=""

if [ -n "$rate_used" ]; then
    rate_int=$(printf "%.0f" "$rate_used")

    if (( $(echo "$rate_used < 50" | bc -l) )); then
        rate_color=$'\033[32m'  # Green for 0-50%
    elif (( $(echo "$rate_used < 75" | bc -l) )); then
        rate_color=$'\033[33m'  # Yellow for 50-75%
    else
        rate_color=$'\033[31m'  # Red for 75-100%
    fi

    bar_length=10
    total_blocks=$(echo "$rate_used * $bar_length / 100" | bc -l)
    full_blocks=$(printf "%.0f" "$(echo "$total_blocks" | bc -l | awk '{print int()}')")
    fraction=$(echo "$total_blocks - $full_blocks" | bc -l)

    shade_char=""
    if (( $(echo "$fraction >= 0.875" | bc -l) )); then
        shade_char="█"
        full_blocks=$((full_blocks + 1))
    elif (( $(echo "$fraction >= 0.625" | bc -l) )); then
        shade_char="▓"
    elif (( $(echo "$fraction >= 0.375" | bc -l) )); then
        shade_char="▒"
    elif (( $(echo "$fraction >= 0.125" | bc -l) )); then
        shade_char="░"
    fi

    rate_bar=$'\033[0m'"["
    rate_bar+="${rate_color}"
    for ((i=0; i<full_blocks; i++)); do rate_bar+="█"; done
    [ -n "$shade_char" ] && [ "$full_blocks" -lt "$bar_length" ] && rate_bar+="$shade_char"
    rate_bar+=$'\033[0m'
    current_length=$full_blocks
    [ -n "$shade_char" ] && [ "$full_blocks" -lt "$bar_length" ] && current_length=$((current_length + 1))
    empty=$((bar_length - current_length))
    for ((i=0; i<empty; i++)); do rate_bar+=" "; done
    rate_bar+="]"

    time_str=""
    if [ -n "$rate_resets_at" ]; then
        now=$(date +%s)
        remaining_secs=$((rate_resets_at - now))
        if [ "$remaining_secs" -gt 0 ]; then
            hours=$((remaining_secs / 3600))
            mins=$(( (remaining_secs % 3600) / 60 ))
            if [ "$hours" -gt 0 ]; then
                time_str=" · ${hours}h ${mins}m left"
            else
                time_str=" · ${mins}m left"
            fi
        fi
    fi

    rate_str=" $rate_bar ${rate_int}%${time_str}"
fi

# Get git branch for the current working directory
git_branch=""
if git_branch_out=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null); then
    git_branch="$git_branch_out"
fi

# Output
printf "\033[36m%s\033[0m" "$short_dir"
[ -n "$git_branch" ] && printf " \033[35m(%s)\033[0m" "$git_branch"
[ -n "$context_str" ] && printf "\033[33m%s\033[0m" "$context_str"
[ -n "$rate_str" ] && printf "\033[33m%s\033[0m" "$rate_str"
