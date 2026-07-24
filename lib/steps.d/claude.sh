# Claude Code: the CLI, skills, and the marketplaces/plugins in plugins.txt.

register claude "Claude Code           (marketplaces, plugins, skills)"

step_claude() {
  task "Claude Code" _claude_cli
  has claude || { ui_warn "claude not on PATH, skipping plugins and skills"; return 0; }

  task "~/.claude/CLAUDE.md" ensure_link "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

  # Link each skill on its own so other skills already on the machine stay put.
  mkdir -p "$HOME/.claude/skills"
  local skill name
  for skill in "$DOTFILES"/claude/skills/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    task "skill: $name" ensure_link "${skill%/}" "$HOME/.claude/skills/$name"
  done

  local market repo plugin_list
  while read -r market repo plugin_list; do
    case "$market" in ''|\#*) continue ;; esac
    task "marketplace: $market" _claude_market "$market" "$repo" "$plugin_list"
  done < "$DOTFILES/claude/plugins.txt"
}

_claude_cli() {
  if has claude; then
    task_skip "already installed"
    return 0
  fi
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
}

_claude_market() {
  local market="$1" repo="$2" plugin_list="$3" plugin installed=0
  claude plugin marketplace add "$repo" >/dev/null 2>&1 || true

  [ "$plugin_list" = "-" ] && { task_note "registered, no plugins"; return 0; }

  local IFS=','
  for plugin in $plugin_list; do
    if claude plugin install "$plugin@$market" >/dev/null 2>&1; then
      installed=$((installed + 1))
    fi
  done
  if [ "$installed" = 0 ]; then
    task_skip "plugins already installed"
  else
    task_note "installed $installed plugin(s)"
  fi
}
