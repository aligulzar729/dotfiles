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
# Untracked: packages this machine keeps but other machines should not install.
local_file="$HOME/.Brewfile.local"
[ -f "$local_file" ] && files="$files $local_file"
# shellcheck disable=SC2086  # deliberate word split
declared=" $(awk -F'"' '/^(brew|cask) /{print $2}' $files | sed 's|.*/||' | tr '\n' ' ') "

undeclared=""
# Tap formulae come back as tap/name; declared holds bare names.
for pkg in $(brew leaves --installed-on-request 2>/dev/null); do
  case "$declared" in
    *" ${pkg##*/} "*) ;;
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
ui_info "y adds to the shared Brewfile, l to ~/.Brewfile.local (this machine only),"
ui_info "n leaves it, q stops here."
printf '\n'

added=0 added_local=0
for pkg in $undeclared; do
  printf '  %s? [y/l/N/q] ' "$pkg"
  IFS= read -r reply </dev/tty || reply=n
  case "$reply" in
    [qQ]*) break ;;
    [yY]*)
      printf 'brew "%s"\n' "$pkg" >> "$DOTFILES/Brewfile"
      added=$((added + 1))
      ;;
    [lL]*)
      printf 'brew "%s"\n' "$pkg" >> "$local_file"
      added_local=$((added_local + 1))
      ;;
  esac
done

printf '\n'
[ "$added" -gt 0 ] && ui_info "added $added package(s) to Brewfile. Review the diff before committing."
[ "$added_local" -gt 0 ] && ui_info "added $added_local package(s) to $local_file"
[ $((added + added_local)) -eq 0 ] && ui_info "nothing added"
exit 0
