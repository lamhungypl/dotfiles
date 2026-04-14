---
name: statusline-setup
description: Configure Claude Code's statusline with a Powerlevel10k-inspired theme showing directory, git branch, lines changed, and context usage progress bar.
---

# Statusline Configuration Skill

## Overview

This skill configures Claude Code's statusline with a Powerlevel10k-inspired theme that displays:
- **Shortened directory** - Shows `~/currentDir` format
- **Git branch** - Displays branch name with `` icon
- **Lines changed** - Shows additions (green `+N`) and deletions (red `-N`)
- **Context usage** - Progress bar with gradient shading (green/yellow/red)
- **Rate limit usage** - 5-hour quota progress bar with reset countdown (e.g. `[██        ] 23% · 2h 15m left`)

## Pre-Installation Checks

Before installing, you MUST check for existing configurations:

### 1. Check for existing statusline configuration

Read `~/.claude/settings.json` and check if a `statusLine` key already exists.

### 2. Check for existing statusline script

Check if `~/.claude/statusline-command.sh` already exists.

### 3. Handle existing configuration

**If either an existing `statusLine` configuration OR an existing script is found:**

Use the `AskUserQuestion` tool to ask the user:

```
Question: "You already have a statusline configuration. Do you want to replace it with the Powerlevel10k-inspired theme?"
Options:
  - "Yes, replace it" - Proceed with installation
  - "No, keep my current setup" - Abort installation
```

**If the user chooses to replace AND an existing script file exists at a different path:**

Use the `AskUserQuestion` tool to ask:

```
Question: "Should I delete your old statusline script?"
Options:
  - "Yes, delete it" - Delete the old script file
  - "No, keep it" - Leave the old script file in place
```

**If the user chooses not to replace:** Stop here and inform the user that the existing configuration has been preserved.

---

## Installation Instructions

Follow these steps to configure the statusline:

### Step 1: Write the statusline script

Write the following bash script to `~/.claude/statusline-command.sh`:

```bash
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
cd "$cwd" 2>/dev/null || true
git_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo '')
git_status_str=""

if [ -n "$git_branch" ]; then
    git_status_str=" $git_branch"
fi

# Get Claude's session lines added/removed
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
lines_added_str=""
lines_removed_str=""
[ "$lines_added" != "0" ] && lines_added_str="+$lines_added"
[ "$lines_removed" != "0" ] && lines_removed_str="-$lines_removed"

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
    full_blocks=$(printf "%.0f" "$(echo "$total_blocks" | bc -l | awk '{print int($1)}')")
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
    full_blocks=$(printf "%.0f" "$(echo "$total_blocks" | bc -l | awk '{print int($1)}')")
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

# Output
printf "\033[36m%s\033[0m" "$short_dir"
[ -n "$git_status_str" ] && printf "\033[34m%s\033[0m" "$git_status_str"
if [ -n "$lines_added_str" ] || [ -n "$lines_removed_str" ]; then
    printf " "
    [ -n "$lines_added_str" ] && printf "\033[32m%s\033[0m" "$lines_added_str"
    [ -n "$lines_added_str" ] && [ -n "$lines_removed_str" ] && printf " "
    [ -n "$lines_removed_str" ] && printf "\033[31m%s\033[0m" "$lines_removed_str"
fi
[ -n "$context_str" ] && printf "\033[33m%s\033[0m" "$context_str"
[ -n "$rate_str" ] && printf "\033[33m%s\033[0m" "$rate_str"
```

### Step 2: Make the script executable

```bash
chmod +x ~/.claude/statusline-command.sh
```

### Step 3: Update settings.json

Add or merge the following configuration into `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

If the file already exists, merge the `statusLine` key into the existing configuration.

## Verification

After installation:
1. Restart Claude Code
2. The statusline should appear at the bottom showing:
   - Current directory in cyan
   - Git branch with  icon in blue (if in a git repo)
   - Lines added/removed in green/red (if there are changes)
   - Context usage progress bar with percentage
   - 5-hour rate limit bar with reset countdown (e.g. `[██        ] 23% · 2h 15m left`) — only visible for Pro/Max subscribers after the first API response

## Customization

You can modify `~/.claude/statusline-command.sh` to customize:
- Colors (change ANSI codes at the top)
- Progress bar width (change `bar_width` variable)
- Progress bar characters (change `█` and `░`)
- Directory format (modify `get_short_dir` function)
