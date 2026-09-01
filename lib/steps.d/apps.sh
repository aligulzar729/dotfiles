# shellcheck shell=bash
# Desktop apps. On macOS they come from Brewfile.macos, so this step is Linux.

register apps "Desktop apps          (Ghostty, Zed, GitHub Desktop Plus, Bitwarden)"

step_apps() {
  # Ghostty has no Windows build, so its WSL hint lands on a page with nothing
  # for it. Windows Terminal is the answer there.
  #                          binary   pkg      script                      download
  task "Ghostty"             _app ghostty ghostty -                          https://ghostty.org/download
  task "Zed"                 _app zed     -       https://zed.dev/install.sh  https://zed.dev/download
  task "GitHub Desktop Plus" _app -       -       -                          https://github.com/pol-rivero/GitHub-Desktop-Plus/releases/latest
  task "Bitwarden"           _bitwarden
}

# Pass - for any field that does not apply.
_app() {
  local bin="$1" pkg="$2" script="$3" url="$4"
  is_macos && { task_skip "installed as a cask by the packages step"; return 0; }
  [ "$HAS_GUI" = 0 ] && { task_skip "WSL, install it on the Windows side: $url"; return 0; }
  [ "$bin" != - ] && has "$bin" && { task_skip "already installed"; return 0; }

  if [ "$script" != - ]; then
    curl -f "$script" | sh
  elif [ "$pkg" != - ] && { [ "$PKG" = pacman ] || [ "$PKG" = dnf ]; }; then
    sysinstall "$pkg"
  else
    task_note "download: $url"
  fi
}

# A cask on macOS. On Linux it has to come from Flathub or snap, whose socket
# roots the ssh step already searches.
_bitwarden() {
  is_macos && { task_skip "installed as a cask by the packages step"; return 0; }
  [ "$HAS_GUI" = 0 ] && { task_skip "WSL, install it on the Windows side: https://bitwarden.com/download/"; return 0; }
  if has bitwarden \
     || flatpak info com.bitwarden.desktop >/dev/null 2>&1 \
     || snap list bitwarden >/dev/null 2>&1; then
    task_skip "already installed"
    return 0
  fi

  # --user avoids sudo, whose password prompt task() would swallow into the log.
  # snap has no unprivileged mode, so hand that one back to the user.
  if has flatpak; then
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub com.bitwarden.desktop
  elif has snap; then
    task_note "needs sudo, run: sudo snap install bitwarden"
  else
    task_note "no flatpak or snap here, download: https://bitwarden.com/download/"
  fi
}
