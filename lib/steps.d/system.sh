# Bootstrap: build tools, Homebrew, the CLI stack, fonts.

register prereqs  "Build prerequisites   (compiler + curl/git, Linux only)"
register homebrew "Homebrew              (package manager, all platforms)"
register packages "CLI stack             (starship atuin zoxide fzf eza bat rg fd mailpit)"
register fonts    "JetBrainsMono Nerd Font (prompt + terminal glyphs)"

step_prereqs() {
  task "Build prerequisites" _prereqs
}

_prereqs() {
  if is_macos; then
    task_skip "macOS ships them with the Command Line Tools"
    return 0
  fi
  case "$PKG" in
    apt-get) sysinstall build-essential procps curl file git ca-certificates unzip ;;
    dnf)     sysinstall @development-tools procps-ng curl file git unzip ;;
    pacman)  sysinstall base-devel procps-ng curl file git unzip ;;
    *)       sysinstall curl file git unzip ;;
  esac
}

step_homebrew() {
  task "Homebrew" _homebrew
}

_homebrew() {
  if load_brew; then
    task_skip "already installed ($(brew --version | head -1))"
    return 0
  fi
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew || return 1
}

step_packages() {
  load_brew || { ui_warn "Homebrew missing, run the homebrew step first"; return 0; }
  task "CLI stack" _brew_bundle "$DOTFILES/Brewfile"
  task "ani-cli"   _ani_cli
  if is_macos; then
    task "Trust taps" _trust_taps "$DOTFILES/Brewfile.macos"
    task "macOS casks" _brew_bundle "$DOTFILES/Brewfile.macos"
  fi
}

# ani-cli self-updates and has no brew formula, so fetch the latest rather than
# tracking a copy that churns. Skip if a real file is already there; leave
# updates to `ani-cli -U`.
_ani_cli() {
  local dst="$HOME/.local/bin/ani-cli"
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    task_skip "already installed (update with: ani-cli -U)"
    return 0
  fi
  mkdir -p "$HOME/.local/bin"
  rm -f "$dst"
  curl -fsSL -o "$dst" https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli
  chmod +x "$dst"
}

# brew refuses casks from third-party taps until they are trusted. Trust every
# tap the Brewfile declares so the bundle below does not stop on the prompt.
_trust_taps() {
  local file="$1" tap
  while read -r tap; do
    [ -n "$tap" ] && brew trust "$tap" >/dev/null 2>&1 || true
  done < <(awk -F'"' '/^tap /{print $2}' "$file")
}

_brew_bundle() {
  local file="$1"
  if brew bundle check --file="$file" >/dev/null 2>&1; then
    task_skip "everything in $(basename "$file") is present"
    return 0
  fi
  brew bundle --file="$file"
}

step_fonts() {
  task "JetBrainsMono Nerd Font" _fonts
}

_fonts() {
  if is_macos; then
    task_skip "installed as a cask by the packages step"
    return 0
  fi
  local dir="$HOME/.local/share/fonts"
  if [ -n "$(find "$dir" -iname 'JetBrainsMono*Nerd*' -print -quit 2>/dev/null)" ]; then
    task_skip "already installed"
    return 0
  fi
  mkdir -p "$dir"
  curl -fLo "$dir/JetBrainsMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -oq "$dir/JetBrainsMono.zip" -d "$dir"
  rm -f "$dir/JetBrainsMono.zip"
  has fc-cache && fc-cache -f "$dir"
  return 0
}
