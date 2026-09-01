# shellcheck shell=bash
# macOS system preferences. Every key is written out in full so any single one
# can be undone with: defaults delete <domain> <key>

register macos "macOS defaults        (keyboard, Finder, Dock, screenshots)"

step_macos() {
  if ! is_macos; then
    task "macOS defaults" _macos_skip
    return 0
  fi
  # Restarts Finder and the Dock, so it asks first even under --all.
  if [ "$UI_TTY" != 1 ]; then
    task "macOS defaults" _macos_skip_headless
    return 0
  fi
  if ! ui_confirm "Apply macOS defaults? This restarts Finder and the Dock."; then
    task "macOS defaults" _macos_declined
    return 0
  fi

  task "Keyboard"    _macos_keyboard
  task "Finder"      _macos_finder
  task "Dock"        _macos_dock
  task "Screenshots" _macos_screenshots
  task "Restart UI"  _macos_restart
}

_macos_skip()          { task_skip "macOS only"; }
_macos_skip_headless() { task_skip "needs a terminal, run ./install.sh macos"; }
_macos_declined()      { task_skip "declined"; }

_macos_keyboard() {
  # ApplePressAndHoldEnabled must be off or holding a key opens the accent
  # menu instead of repeating.
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Smart punctuation mangles code pasted into non-editor apps.
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  task_note "repeat 2/15, autocorrect and smart quotes off"
}

_macos_finder() {
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
  defaults write com.apple.finder FXDefaultSearchScope -string SCcf
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  task_note "list view, path bar, real extensions, no .DS_Store on shares"
}

_macos_dock() {
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0.15
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock mru-spaces -bool false

  task_note "autohide with no delay, no recents, spaces stay put"
}

_macos_screenshots() {
  local dir="$HOME/Screenshots"
  mkdir -p "$dir"
  defaults write com.apple.screencapture location -string "$dir"
  defaults write com.apple.screencapture type -string png
  defaults write com.apple.screencapture disable-shadow -bool true

  task_note "png, no shadow, saved to ~/Screenshots"
}

# Nothing above applies until these reload their preferences.
_macos_restart() {
  killall Finder >/dev/null 2>&1 || true
  killall Dock >/dev/null 2>&1 || true
  killall SystemUIServer >/dev/null 2>&1 || true
  task_note "undo any single setting with: defaults delete <domain> <key>"
}
