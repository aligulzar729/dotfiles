# shellcheck shell=bash
# Verifies the machine instead of changing it. Nothing in here writes.
# Separate from the install steps on purpose: a step that reports what it did
# cannot also report whether it worked.

register doctor "Health check          (verify, never change)"

step_doctor() {
  task "Homebrew"          _dr_brew
  task "node + npx"        _dr_node
  task "Symlinks"          _dr_links
  task "Login shell"       _dr_shell
  task "Nerd Font"         _dr_font
  task "SSH config"        _dr_ssh_config
  task "Bitwarden agent"   _dr_ssh_agent
  task "Packages"          _dr_packages
  task "Claude plugins"    _dr_claude_plugins
  task "Claude skills"     _dr_claude_skills
  task "CLAUDE.md"         _dr_claude_md
  task "Commit guard"      _dr_hooks
  task "History"           _dr_history
  task "Deferred work"     _dr_debt
}

_dr_brew() {
  load_brew >/dev/null 2>&1 || { task_note "not on PATH, run the homebrew step"; return 1; }
  task_skip "$(brew --prefix)"
}

_dr_node() {
  has npx || { task_note "missing, the claude step will skip every third-party skill"; return 1; }
  task_skip "$(node --version 2>/dev/null)"
}

# A name in `ls` proves nothing: the target may be gone, or replaced by a real
# file someone edited in place.
_dr_links() {
  local src rel dst broken=0 wrong=0 missing=0
  while IFS= read -r src; do
    rel="${src#"$DOTFILES/home/"}"
    dst="$HOME/$rel"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      missing=$((missing + 1)); echo "missing: $dst"
    elif [ ! -L "$dst" ]; then
      wrong=$((wrong + 1)); echo "not a symlink: $dst"
    elif [ ! -e "$dst" ]; then
      broken=$((broken + 1)); echo "dangling: $dst"
    fi
  done < <(find "$DOTFILES/home" -type f ! -name '*.example' | sort)

  if [ $((broken + wrong + missing)) -gt 0 ]; then
    task_note "$missing missing, $wrong not links, $broken dangling: run ./install.sh link"
    return 1
  fi
  task_skip "all linked"
}

_dr_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)" || { task_note "zsh not installed"; return 1; }
  [ "${SHELL:-}" = "$zsh_path" ] || { task_note "SHELL is ${SHELL:-unset}, not $zsh_path"; return 1; }
  task_skip "zsh"
}

_dr_font() {
  if is_macos; then
    [ -n "$(find /Library/Fonts "$HOME/Library/Fonts" -iname 'JetBrainsMono*Nerd*' -print -quit 2>/dev/null)" ] \
      || { task_note "not installed, run the packages step"; return 1; }
  elif [ "$HAS_GUI" = 0 ]; then
    task_skip "WSL, the font lives on the Windows side"
    return 0
  else
    [ -n "$(find "$HOME/.local/share/fonts" -iname 'JetBrainsMono*Nerd*' -print -quit 2>/dev/null)" ] \
      || { task_note "not installed, run the fonts step"; return 1; }
  fi
  task_skip "installed"
}

# One broken file in config.d breaks every host at once.
_dr_ssh_config() {
  ssh -G dotfiles-config-check >/dev/null 2>&1 || { task_note "~/.ssh/config does not parse"; return 1; }
  grep -q 'config\.d' "$HOME/.ssh/config" 2>/dev/null \
    || { task_note "no config.d include, run ./install.sh ssh"; return 1; }
  task_skip "parses, include present"
}

# Ask the agent for keys. A socket file outlives the process that served it.
_dr_ssh_agent() {
  local sock keys
  sock="$(ssh -G dotfiles-config-check 2>/dev/null | awk '/^identityagent /{print $2}')"
  [ -n "$sock" ] || { task_note "no IdentityAgent configured, run ./install.sh ssh"; return 1; }
  sock="${sock/#\~/$HOME}"

  SSH_AUTH_SOCK="$sock" ssh-add -l >/dev/null 2>&1
  case $? in
    0) keys="$(SSH_AUTH_SOCK="$sock" ssh-add -l | wc -l | tr -d ' ')"
       task_skip "$keys key(s) loaded" ;;
    1) task_note "agent reachable but holds no keys: unlock Bitwarden"; return 1 ;;
    *) task_note "nothing listening on $sock: is the Bitwarden SSH agent enabled?"; return 1 ;;
  esac
}

# An undeclared formula is one a rebuild silently drops.
_dr_packages() {
  load_brew >/dev/null 2>&1 || { task_skip "no homebrew"; return 0; }
  local files="$DOTFILES/Brewfile" declared missing=0 extra=0 pkg
  is_macos && files="$files $DOTFILES/Brewfile.macos"

  # shellcheck disable=SC2086  # files is a deliberate word-split list
  declared=" $(awk -F'"' '/^(brew|cask) /{print $2}' $files | sed 's|.*/||' | tr '\n' ' ') "

  for pkg in $declared; do
    brew list --formula "$pkg" >/dev/null 2>&1 && continue
    brew list --cask "$pkg" >/dev/null 2>&1 && continue
    missing=$((missing + 1)); echo "declared but not installed: $pkg"
  done

  # Requested packages only: dependencies are plumbing, not drift.
  for pkg in $(brew leaves --installed-on-request 2>/dev/null); do
    case "$declared" in
      *" $pkg "*) ;;
      *) extra=$((extra + 1)); echo "installed but not in any Brewfile: $pkg" ;;
    esac
  done

  if [ $((missing + extra)) -gt 0 ]; then
    task_note "$missing declared missing, $extra undeclared (a rebuild loses those)"
    return 1
  fi
  task_skip "Brewfile matches the machine"
}

_dr_claude_plugins() {
  has claude || { task_skip "claude not installed"; return 0; }
  local installed missing=0 plugin market list
  installed="$(claude plugin list 2>/dev/null)"

  while read -r market _ list; do
    case "$market" in ''|\#*) continue ;; esac
    [ "$list" = "-" ] && continue
    local IFS=','
    for plugin in $list; do
      case "$installed" in
        *"$plugin@$market"*) ;;
        *) missing=$((missing + 1)); echo "declared but not installed: $plugin@$market" ;;
      esac
    done
    unset IFS
  done < "$DOTFILES/claude/plugins.txt"

  [ "$missing" -gt 0 ] && { task_note "$missing declared plugin(s) not installed: ./install.sh claude"; return 1; }
  task_skip "all declared plugins installed"
}

_dr_claude_skills() {
  local dir="$HOME/.claude/skills" declared missing=0 extra=0 repo list skill name
  [ -d "$dir" ] || { task_skip "no skills directory"; return 0; }

  declared=""
  for name in "$DOTFILES"/claude/skills/*/; do
    [ -d "$name" ] && declared="$declared $(basename "$name")"
  done
  while read -r repo list; do
    case "$repo" in ''|\#*) continue ;; esac
    local IFS=','
    for skill in $list; do declared="$declared $skill"; done
    unset IFS
  done < "$DOTFILES/claude/skills.txt"

  # Deliberately-local skills are declared by a comment, not a repo line.
  declared="$declared $(sed -n 's/^# local-only:[[:space:]]*//p' "$DOTFILES/claude/skills.txt" | tr '\n' ' ')"

  for skill in $declared; do
    [ -e "$dir/$skill" ] || { missing=$((missing + 1)); echo "declared but not on disk: $skill"; }
  done
  for name in "$dir"/*/; do
    [ -d "$name" ] || continue
    skill="$(basename "$name")"
    case " $declared " in
      *" $skill "*) ;;
      *) extra=$((extra + 1)); echo "on disk but declared nowhere: $skill" ;;
    esac
  done

  if [ $((missing + extra)) -gt 0 ]; then
    task_note "$missing declared missing, $extra undeclared (a rebuild loses those)"
    return 1
  fi
  task_skip "declared and installed agree"
}

# CLAUDE.md loads every session, so a skill it names but you lack is an
# instruction nothing can follow.
_dr_claude_md() {
  local f="$DOTFILES/claude/CLAUDE.md" skill missing=0
  [ -f "$f" ] || { task_skip "none"; return 0; }
  while read -r skill; do
    [ -z "$skill" ] && continue
    find "$HOME/.claude/skills" "$HOME/.claude/plugins/cache" -maxdepth 4 -type d -name "$skill" \
      -print -quit 2>/dev/null | grep -q . && continue
    missing=$((missing + 1)); echo "CLAUDE.md names a skill that is not installed: $skill"
  done < <(grep -oE '/[a-z0-9][a-z0-9-]+ skill' "$f" | sed 's|^/||; s| skill$||' | sort -u)

  [ "$missing" -gt 0 ] && { task_note "$missing named skill(s) missing"; return 1; }
  task_skip "every named skill is installed"
}

_dr_hooks() {
  local path
  path="$(git -C "$DOTFILES" config --local core.hooksPath 2>/dev/null || true)"
  [ "$path" = hooks ] || { task_note "core.hooksPath is '${path:-unset}', run ./install.sh link"; return 1; }
  [ -x "$DOTFILES/hooks/pre-commit" ] || { task_note "hooks/pre-commit is not executable"; return 1; }
  # Run it, rather than checking that a file with that name exists.
  "$DOTFILES/hooks/pre-commit" >/dev/null 2>&1
  [ $? -le 1 ] || { task_note "hooks/pre-commit errored, run it by hand"; return 1; }
  task_skip "pre-commit active"
}

# The commit guard only sees new commits. History predates it.
_dr_history() {
  git -C "$DOTFILES" log -p --all 2>/dev/null \
    | awk -v allow_file="$DOTFILES/.pii-allow" -f "$DOTFILES/lib/scan.awk" \
    || { task_note "secrets or PII in git history, see the log"; return 1; }
  task_skip "no secrets in git history"
}

# Reports, never fails: the count exists so "later" does not become "never".
_dr_debt() {
  local n
  n="$(grep -rn 'ponytail:' "$DOTFILES/lib" "$DOTFILES/install.sh" "$DOTFILES/home" 2>/dev/null | grep -c . || true)"
  [ "${n:-0}" -gt 0 ] && { task_skip "$n deliberate shortcut(s) marked"; return 0; }
  task_skip "none marked"
}
