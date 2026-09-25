# shellcheck shell=bash
# Symlink everything under home/ into ~.

register link "Symlink dotfiles      (.zshrc, starship, atuin, eza, ghostty, zed)"

step_link() {
  local src rel
  while IFS= read -r src; do
    rel="${src#"$DOTFILES/home/"}"
    task "~/$rel" ensure_link "$src" "$HOME/$rel"
  done < <(find "$DOTFILES/home" -type f ! -name '*.example' | sort)

  task "~/.zshrc.local" _zshrc_local
  task "Git hooks"      _git_hooks
}

_zshrc_local() {
  if [ -f "$HOME/.zshrc.local" ]; then
    task_skip "already present, not overwritten"
    return 0
  fi
  cp "$DOTFILES/home/.zshrc.local.example" "$HOME/.zshrc.local"
  task_note "created, put secrets and per-machine config here"
}

# core.hooksPath rather than copying into .git/hooks, so the hook stays tracked
# and a fresh clone gets the current one. Repo-local: setting it globally would
# override every other repository's hooks.
_git_hooks() {
  local current
  current="$(git -C "$DOTFILES" config --local core.hooksPath 2>/dev/null || true)"
  if [ "$current" = hooks ]; then
    task_skip "pre-commit PII scan already wired"
    return 0
  fi
  git -C "$DOTFILES" config --local core.hooksPath hooks
  chmod +x "$DOTFILES/hooks/"* 2>/dev/null || true
  task_note "pre-commit scans staged changes for secrets and PII"
}
