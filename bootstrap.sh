#!/usr/bin/env bash
#
# One-liner entry point for a machine with nothing on it:
#
#   curl -fsSL https://raw.githubusercontent.com/aligulzar729/dotfiles/main/bootstrap.sh | bash
#
# Clones the repo and hands over to install.sh. Everything else lives there;
# this exists only because a fresh box may not have the repo yet.

set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/aligulzar729/dotfiles}"
DEST="${DOTFILES_DIR:-$HOME/Projects/dotfiles}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required first:" >&2
  if [ "$(uname -s)" = Darwin ]; then
    echo "  xcode-select --install" >&2
  else
    echo "  sudo apt-get install -y git   # or dnf/pacman equivalent" >&2
  fi
  exit 1
fi

if [ -d "$DEST/.git" ]; then
  echo "==> updating $DEST"
  git -C "$DEST" pull --ff-only --quiet || true
else
  echo "==> cloning into $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --quiet "$REPO" "$DEST"
fi

cd "$DEST"
# Piped into bash, stdin is the script itself, so install.sh could not read a
# picker. Point at the tty when there is one, and require named steps if not.
if [ -t 1 ] && [ -r /dev/tty ]; then
  exec ./install.sh "$@" </dev/tty
fi
echo "==> not a terminal: run ./install.sh --all, or name steps"
