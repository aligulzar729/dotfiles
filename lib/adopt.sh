#!/usr/bin/env bash
#
# Adds packages you installed by hand into the Brewfile, so `dots doctor` stops
# reporting drift you have already decided to keep. A check people learn to
# scroll past is worse than no check.

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$DOTFILES/lib/ui.sh"
. "$DOTFILES/lib/core.sh"

detect_platform
load_brew >/dev/null 2>&1 || { ui_error "Homebrew not on PATH"; exit 1; }

files="$DOTFILES/Brewfile"
is_macos && files="$files $DOTFILES/Brewfile.macos"
# shellcheck disable=SC2086  # deliberate word split
declared=" $(awk -F'"' '/^(brew|cask) /{print $2}' $files | sed 's|.*/||' | tr '\n' ' ') "

undeclared=""
for pkg in $(brew leaves --installed-on-request 2>/dev/null); do
  case "$declared" in
    *" $pkg "*) ;;
    *) undeclared="$undeclared $pkg" ;;
  esac
done

if [ -z "${undeclared// /}" ]; then
  ui_info "nothing to adopt, the Brewfile matches the machine"
  exit 0
fi

printf '\n'
ui_info "Installed on request but not in any Brewfile:"
printf '\n'
for pkg in $undeclared; do
  printf '    %-20s %s\n' "$pkg" "$(brew desc --eval-all "$pkg" 2>/dev/null | sed "s/^$pkg: //" | cut -c1-52)"
done
if [ "$UI_TTY" != 1 ]; then
  ui_info "run this from a terminal to adopt them"
  exit 0
fi

printf '\n'
ui_info "y adds to Brewfile, n leaves it, q stops here."
printf '\n'

added=0
for pkg in $undeclared; do
  printf '  %s? [y/N/q] ' "$pkg"
  IFS= read -r reply </dev/tty || reply=n
  case "$reply" in
    [qQ]*) break ;;
    [yY]*)
      printf 'brew "%s"\n' "$pkg" >> "$DOTFILES/Brewfile"
      added=$((added + 1))
      ;;
  esac
done

printf '\n'
if [ "$added" -gt 0 ]; then
  ui_info "added $added package(s) to Brewfile. Review the diff before committing."
else
  ui_info "nothing added"
fi
