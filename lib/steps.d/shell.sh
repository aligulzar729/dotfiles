# zsh: oh-my-zsh + custom plugins, and making zsh the login shell.

register zsh   "oh-my-zsh             (framework + 5 custom plugins)"
register shell "Login shell           (make zsh the default)"

OMZ_PLUGINS="
zsh-autosuggestions          https://github.com/zsh-users/zsh-autosuggestions
zsh-syntax-highlighting      https://github.com/zsh-users/zsh-syntax-highlighting
zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search
zsh-completions              https://github.com/zsh-users/zsh-completions
artisan                      https://github.com/jessarcher/zsh-artisan
"

step_zsh() {
  task "oh-my-zsh" _omz

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
  mkdir -p "$custom"

  local name repo
  while read -r name repo; do
    [ -z "$name" ] && continue
    task "plugin: $name" ensure_repo "$custom/$name" "$repo"
  done <<EOF
$OMZ_PLUGINS
EOF
}

_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    task_skip "already installed"
    return 0
  fi
  # Without KEEP_ZSHRC the installer replaces the .zshrc the link step needs.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

step_shell() {
  task "Default shell" _login_shell
}

_login_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)" || { task_skip "zsh not installed yet"; return 0; }

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    task_skip "zsh is already the login shell"
    return 0
  fi
  grep -qxF "$zsh_path" /etc/shells 2>/dev/null \
    || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$zsh_path" || { task_note "run manually: chsh -s $zsh_path"; return 0; }
}
