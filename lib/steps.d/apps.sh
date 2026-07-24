# Desktop apps. On macOS they come from Brewfile.macos, so this step is Linux.

register apps "Desktop apps          (Ghostty, Zed, GitHub Desktop Plus)"

step_apps() {
  #                          binary   pkg      script                      download
  task "Ghostty"             _app ghostty ghostty -                          https://ghostty.org/download
  task "Zed"                 _app zed     -       https://zed.dev/install.sh  -
  task "GitHub Desktop Plus" _app -       -       -                          https://github.com/pol-rivero/GitHub-Desktop-Plus/releases/latest
}

# macOS and WSL handled up front. On Linux: a script install wins, else a
# distro package on Arch/Fedora, else just print the download link. Use - to
# skip a field.
_app() {
  local bin="$1" pkg="$2" script="$3" url="$4"
  is_macos && { task_skip "installed as a cask by the packages step"; return 0; }
  [ "$HAS_GUI" = 0 ] && { task_skip "WSL, install the Windows build instead"; return 0; }
  [ "$bin" != - ] && has "$bin" && { task_skip "already installed"; return 0; }

  if [ "$script" != - ]; then
    curl -f "$script" | sh
  elif [ "$pkg" != - ] && { [ "$PKG" = pacman ] || [ "$PKG" = dnf ]; }; then
    sysinstall "$pkg"
  else
    task_note "download: $url"
  fi
}
