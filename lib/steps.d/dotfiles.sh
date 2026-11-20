# shellcheck shell=bash
# Symlink everything under home/ into ~, except .zshrc (see _zshrc_stub).

register link "Symlink dotfiles      (.zshrc, starship, atuin, eza, ghostty, zed)"

step_link() {
  local src rel
  while IFS= read -r src; do
    rel="${src#"$DOTFILES/home/"}"
    task "~/$rel" ensure_link "$src" "$HOME/$rel"
  done < <(find "$DOTFILES/home" -type f ! -name '*.example' ! -path "$DOTFILES/home/.zshrc" | sort)

  task "~/.zshrc"       _zshrc_stub
  task "~/.zshrc.local" _zshrc_local
  task "Git hooks"      _git_hooks
}

# ~/.zshrc is a real, untracked file that sources the repo's .zshrc. As a
# symlink, installers that append to ~/.zshrc (Herd, Flock) wrote machine paths
# into the tracked file.
_zshrc_stub() {
  local dst="$HOME/.zshrc" src="$DOTFILES/home/.zshrc"
  if [ -f "$dst" ] && [ ! -L "$dst" ] && grep -qF 'home/.zshrc' "$dst"; then
    task_skip "already sources the repo .zshrc"
    return 0
  fi
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up $dst -> $dst.bak"
  fi
  # shellcheck disable=SC2016  # the stub must keep $DOTFILES_DIR and backticks literal
  {
    echo '# Per-machine and untracked. Installers that append to ~/.zshrc land here.'
    echo '# Shared config lives in the repo: edit it with `dots zsh`.'
    echo "export DOTFILES_DIR=\"$DOTFILES\""
    echo 'source "$DOTFILES_DIR/home/.zshrc"'
  } > "$dst"
  task_note "stub that sources $src"
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
