# Symlink everything under home/ into ~.

register link "Symlink dotfiles      (.zshrc, starship, atuin, eza, ghostty, zed)"

step_link() {
  local src rel
  while IFS= read -r src; do
    rel="${src#"$DOTFILES/home/"}"
    task "~/$rel" ensure_link "$src" "$HOME/$rel"
  done < <(find "$DOTFILES/home" -type f ! -name '*.example' | sort)

  task "~/.zshrc.local" _zshrc_local

  if is_macos; then
    task "Ghostty (Application Support)" \
      ensure_link "$HOME/.config/ghostty/config" \
      "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  fi
}

_zshrc_local() {
  if [ -f "$HOME/.zshrc.local" ]; then
    task_skip "already present, not overwritten"
    return 0
  fi
  cp "$DOTFILES/home/.zshrc.local.example" "$HOME/.zshrc.local"
  task_note "created, put secrets and per-machine config here"
}
