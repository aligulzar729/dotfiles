# shellcheck shell=bash
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

  mkdir -p "$HOME/.claude/hooks"
  local hook
  for hook in "$DOTFILES"/claude/hooks/*; do
    [ -f "$hook" ] || continue
    task "hook: $(basename "$hook")" ensure_link "$hook" "$HOME/.claude/hooks/$(basename "$hook")"
  done

  local repo skill_list
  if has npx; then
    while read -r repo skill_list; do
      case "$repo" in ''|\#*) continue ;; esac
      task "skills: $repo" _claude_skills "$repo" "$skill_list"
    done < "$DOTFILES/claude/skills.txt"
    task "skills: prune removed" _claude_prune_skills
  else
    ui_warn "npx not on PATH, skipping third-party skills"
  fi

  local market plugin_list
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

# Third-party skills come from their own repos via the skills CLI, so updates are
# `npx skills update` instead of re-vendoring the files into this repo.
_claude_skills() {
  local repo="$1" skill_list="$2" skill
  local -a args=()

  if [ "$skill_list" = "*" ]; then
    args=(--skill '*')
  else
    local IFS=','
    for skill in $skill_list; do args+=(-s "$skill"); done
    unset IFS
  fi

  # This runs inside a `while read ... done < skills.txt` loop and npx inherits
  # that stdin. Without </dev/null it eats the rest of the file, leaving only
  # the first repo installed.
  npx -y skills@latest add "$repo" -g -a claude-code "${args[@]}" -y </dev/null
}

# Third-party skill names skills.txt lists, one per line. A "*" entry has no
# names to list, so its skills are never pruned.
_claude_listed_skills() {
  local repo list skill
  while read -r repo list; do
    case "$repo" in ''|\#*) continue ;; esac
    [ "$list" = "*" ] && continue
    local IFS=','
    for skill in $list; do printf '%s\n' "$skill"; done
    unset IFS
  done < "$DOTFILES/claude/skills.txt"
}

# The skills CLI only adds, so a skill dropped from skills.txt stayed on every
# machine that had it. The manifest records what this step installed, and only
# those names are removed: skills installed by hand are never touched.
_claude_prune_skills() {
  local manifest="$HOME/.claude/state/dotfiles-skills" listed stale skill removed=0
  listed="$(_claude_listed_skills | sort -u)"
  mkdir -p "$(dirname "$manifest")"

  if [ -f "$manifest" ]; then
    stale="$(comm -23 <(sort -u "$manifest") <(printf '%s\n' "$listed"))"
    for skill in $stale; do
      # Moved into claude/skills/ or kept as local-only: still wanted here.
      [ -e "$DOTFILES/claude/skills/$skill" ] && continue
      grep -qx "# local-only: $skill" "$DOTFILES/claude/skills.txt" && continue
      npx -y skills@latest remove -g -s "$skill" -y </dev/null || echo "could not remove $skill"
      rm -rf "${HOME:?}/.claude/skills/$skill"
      removed=$((removed + 1))
    done
  fi

  printf '%s\n' "$listed" > "$manifest"
  if [ "$removed" -gt 0 ]; then
    task_note "removed $removed skill(s) no longer in skills.txt"
  else
    task_skip "nothing to remove"
  fi
}

_claude_market() {
  local market="$1" repo="$2" plugin_list="$3" plugin installed=0 failed=0 present
  # A path that starts with ./ is a marketplace inside this repo.
  case "$repo" in ./*) repo="$DOTFILES/${repo#./}" ;; esac
  claude plugin marketplace add "$repo" >/dev/null 2>&1 </dev/null || true

  [ "$plugin_list" = "-" ] && { task_note "registered, no plugins"; return 0; }

  local IFS=','
  for plugin in $plugin_list; do
    if claude plugin install "$plugin@$market" >/dev/null 2>&1 </dev/null; then
      installed=$((installed + 1))
      continue
    fi
    # A failed install and an already-installed one both return non-zero, so
    # ask the machine rather than assuming the second.
    present="$(claude plugin list 2>/dev/null)"
    case "$present" in
      *"$plugin@$market"*) ;;
      *) failed=$((failed + 1)); echo "install failed: $plugin@$market" ;;
    esac
  done
  unset IFS

  if [ "$failed" -gt 0 ]; then
    task_note "$failed plugin(s) failed, see the log"
    return 1
  fi
  if [ "$installed" = 0 ]; then
    task_skip "plugins already installed"
  else
    task_note "installed $installed plugin(s)"
  fi
}
