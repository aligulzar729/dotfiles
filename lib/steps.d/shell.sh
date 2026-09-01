# shellcheck shell=bash
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

SHELL_RESULT=""

step_shell() {
  # `sudo tee /etc/shells` and chsh both ask for a password, which task() sends
  # to the log where nobody sees it. Prompt first, record the result after.
  _login_shell_change
  task "Default shell" _login_shell_report
}

_login_shell_change() {
  SHELL_RESULT=""
  local zsh_path
  zsh_path="$(command -v zsh)" || { SHELL_RESULT="zsh not installed yet"; return 0; }

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    SHELL_RESULT="zsh is already the login shell"
    return 0
  fi
  if [ "$UI_TTY" != 1 ]; then
    SHELL_RESULT="needs a password, run manually: chsh -s $zsh_path"
    return 0
  fi

  ui_info "Making zsh your login shell. This asks for your password."
  grep -qxF "$zsh_path" /etc/shells 2>/dev/null \
    || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  if chsh -s "$zsh_path"; then
    SHELL_RESULT="changed"
  else
    SHELL_RESULT="run manually: chsh -s $zsh_path"
  fi
}

_login_shell_report() {
  case "$SHELL_RESULT" in
    changed) task_note "zsh set, active at your next login" ;;
    *)       task_skip "$SHELL_RESULT" ;;
  esac
}
