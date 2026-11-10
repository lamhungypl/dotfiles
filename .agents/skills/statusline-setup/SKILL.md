---
name: statusline-setup
description: Configure Claude Code's statusline with a Powerlevel10k-inspired theme showing directory, git branch, lines changed, context usage bar, and 5h rate limit bar — each on its own line.
---

# Statusline Configuration Skill

## Overview

This skill configures Claude Code's statusline with a Powerlevel10k-inspired theme that displays **3 lines**:
- **Line 1**: Shortened directory (`~/currentDir`), git branch, lines added/removed
- **Line 2**: `ctx` — context usage as a solid filled progress bar with percentage
- **Line 3**: `5h` — 5-hour rate limit as a solid filled progress bar with percentage and reset countdown

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

    # [  label░░░░░░         ]
    # └─ bg fill ─┘└─ empty ─┘
    local bar
    bar="${line_color}["
    bar+="${bg_color}"$'\033[1;97m'"${label}"$'\033[0m'"${bg_color}"   # bold bright-white on bg for contrast
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
2. The statusline should appear at the bottom showing 3 lines:
   - **Line 1**: Directory in cyan, git branch in magenta, `+N -N` lines in green/red
   - **Line 2**: `[ctx          ]  25%` — cyan battery bar for context window usage
   - **Line 3**: `[ 5h          ]  12%  ·  3h 40m left` — magenta battery bar for 5-hour rate limit (Pro/Max only)

## Customization

You can modify `~/.claude/statusline-command.sh` to customize:
- Colors (change ANSI codes at the top)
- Progress bar width (change `bar_width` variable)
- Progress bar characters (change `█` and `░`)
- Directory format (modify `get_short_dir` function)
