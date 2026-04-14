# Dotfiles

Personal dotfiles repo. Contains shell config, editor settings, and Claude Code configuration.

## Structure
- `zshrc`, `gitconfig`, `.ideavimrc` — Shell & editor config
- `dotAgents/` — Claude Code skills, hooks, and config (symlinked into `~/.claude/`)
- `Install.sh`, `install_tools.sh` — Bootstrap scripts

## dotAgents Setup
Run `dotAgents/setup.sh` to symlink skills, hooks, and config into `~/.claude/`.
Copy `dotAgents/.env.example` to `dotAgents/.env.local` and fill in credentials.
