#!/usr/bin/env bash
#
#   ./lib/deploy.sh <host>...   copy the server profile to those hosts
#   ./lib/deploy.sh --all       every host in ~/.ssh/config.d/10-servers.conf
#
# remote/ is a deliberately small set: readline, tmux, vim and a few aliases.
# Servers are for looking at things, so nothing here needs a package installed
# or a plugin manager. It never touches an existing ~/.bashrc beyond adding one
# source line, and never overwrites without keeping a .bak.

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$DOTFILES/lib/ui.sh"

HOSTS_FILE="$HOME/.ssh/config.d/10-servers.conf"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new"

_all_hosts() {
  [ -f "$HOSTS_FILE" ] || return 0
  awk '/^[[:space:]]*Host[[:space:]]/ { print $2 }' "$HOSTS_FILE"
}

_deploy_one() {
  local host="$1"
  # A single here-doc over one ssh: no scp, no rsync, works on a box with
  # neither. -n so ssh does not eat the caller's stdin.
  # shellcheck disable=SC2086  # SSH_OPTS is a deliberate list of flags
  tar -C "$DOTFILES/remote" -cf - . 2>/dev/null | ssh $SSH_OPTS "$host" '
    set -e
    umask 077
    tmp=$(mktemp -d)
    tar -C "$tmp" -xf -
    for pair in "inputrc .inputrc" "tmux.conf .tmux.conf" "vimrc .vimrc" "shrc .dotfiles-shrc"; do
      set -- $pair
      src="$tmp/$1"; dst="$HOME/$2"
      [ -f "$src" ] || continue
      if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp "$dst" "$dst.bak"
      fi
      cp "$src" "$dst"
    done
    mkdir -p "$HOME/.vim/undo" "$HOME/.vim/swap"
    # One idempotent source line rather than rewriting their .bashrc.
    if [ -f "$HOME/.bashrc" ] && ! grep -q "dotfiles-shrc" "$HOME/.bashrc"; then
      printf "\n[ -f ~/.dotfiles-shrc ] && . ~/.dotfiles-shrc\n" >> "$HOME/.bashrc"
    fi
    rm -rf "$tmp"
    echo ok
  ' 2>/dev/null
}

targets=""
case "${1:-}" in
  ''|-h|--help) ui_error "usage: deploy.sh <host>... | --all"; exit 1 ;;
  --all)        targets="$(_all_hosts)" ;;
  *)            targets="$*" ;;
esac

printf '\n'
failed=0
for host in $targets; do
  printf '  %-24s ' "$host"
  if [ "$(_deploy_one "$host")" = ok ]; then
    printf '%s✓%s inputrc, tmux, vim, aliases\n' "$C_GRN" "$C_OFF"
  else
    printf '%s✗%s failed\n' "$C_RED" "$C_OFF"
    failed=$((failed + 1))
  fi
done
printf '\n'
[ "$failed" -gt 0 ] && exit 1
exit 0
