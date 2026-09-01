#!/usr/bin/env bash
#
# Health across the hosts in ~/.ssh/config.d/10-servers.conf. Read-only: it
# runs one command per host and prints what came back.
#
# Not an install step: it reaches out to machines, which is not something
# ./install.sh --all should ever do on its own.

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$DOTFILES/lib/ui.sh"

HOSTS_FILE="$HOME/.ssh/config.d/10-servers.conf"

# The first alias on each Host line. The rest are synonyms for the same box.
_hosts() {
  [ -f "$HOSTS_FILE" ] || return 0
  awk '/^[[:space:]]*Host[[:space:]]/ { print $2 }' "$HOSTS_FILE"
}

# ConnectTimeout only covers the TCP connect. Authentication can still stall,
# for example while Bitwarden waits for you to approve the key, so cap the
# whole call and move on.
_with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local killer=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill -TERM "$killer" 2>/dev/null
  return $rc
}

# -n matters: without it ssh reads the loop's stdin and eats the host list,
# the same way npx did in the claude step.
# shellcheck disable=SC2329  # called indirectly through _with_timeout
_ssh_probe() {
  ssh -n -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new "$1" '
    if [ -r /proc/uptime ]; then
      up=$(awk "{d=int(\$1/86400); h=int((\$1%86400)/3600); print d \"d \" h \"h\"}" /proc/uptime)
      load=$(cut -d" " -f1 /proc/loadavg)
    else
      up=$(uptime | sed -E "s/.*up[[:space:]]+//; s/,[[:space:]]+[0-9]+[[:space:]]+user.*//")
      load=$(uptime | sed -E "s/.*averages?:[[:space:]]*//" | cut -d, -f1 | tr -d " ")
    fi
    disk=$(df -h / | awk "NR==2 {print \$5}")
    reboot=no
    [ -f /var/run/reboot-required ] && reboot=YES
    printf "%s|%s|%s|%s" "$up" "$disk" "$load" "$reboot"
  ' 2>/dev/null
}

_probe() { _with_timeout "${DOTS_SSH_TIMEOUT:-25}" _ssh_probe "$1"; }

printf '\n  %-22s %-18s %-6s %-6s %s\n' HOST UPTIME DISK LOAD REBOOT
printf '  %s\n' "------------------------------------------------------------------"

unreachable=0
for host in $(_hosts); do
  if out="$(_probe "$host")" && [ -n "$out" ]; then
    IFS='|' read -r up disk load reboot <<EOF
$out
EOF
    # Anything over 90% full is the thing you actually wanted to know.
    case "$disk" in
      9[0-9]%|100%) disk="$C_RED$disk$C_OFF" ;;
    esac
    [ "$reboot" = YES ] && reboot="$C_YLW$reboot$C_OFF"
    printf '  %-22s %-18s %-6b %-6s %b\n' "$host" "$up" "$disk" "$load" "$reboot"
  else
    printf '  %-22s %sunreachable%s\n' "$host" "$C_RED" "$C_OFF"
    unreachable=$((unreachable + 1))
  fi
done
printf '\n'
[ "$unreachable" -gt 0 ] && exit 1
exit 0
