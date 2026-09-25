#!/usr/bin/env bash
#
#   ./lib/sshable.sh <name> [--key "<pubkey>"]... [--save]
#
#   <name>    Tailscale machine name and ssh alias, e.g. office-mac
#   --key     also authorize this public key, for a machine without
#             Bitwarden desktop or for a phone app's own key. Repeatable.
#   --save    append the Host block to this machine's 10-servers.conf too
#
# Opt-in, not an install step: it opens a network service, and it needs sudo,
# whose password prompt task() would swallow into the log. Safe to re-run.
#
# In order: authorized_keys gets the Bitwarden agent's public keys, sshd is
# locked to keys only and this user, sshd is switched on, macOS stops sleeping
# on power, and Tailscale joins the machine to your tailnet as <name>, so it is
# reachable from anywhere without opening a port on any router.
#
# Undo: delete /etc/ssh/sshd_config.d/01-dotfiles.conf, turn off Remote Login
# (macOS) or `systemctl disable --now ssh` (Linux), and log out of Tailscale.
#
# Runs on macOS's bash 3.2, and on Linux with systemd or OpenRC and any
# package manager core.sh knows (apt, dnf, pacman, zypper, apk).

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$DOTFILES/lib/ui.sh"
# core.sh truncates $LOG_FILE when sourced; point it away from the install log.
LOG_FILE=/dev/null
. "$DOTFILES/lib/core.sh"
detect_platform

# Unset under sudo -i, in containers and in cron.
USER="${USER:-$(id -un)}"

USAGE='usage: sshable.sh <name> [--key "<pubkey>"]... [--save]'
NAME="" SAVE=0
EXTRA_KEYS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --save) SAVE=1 ;;
    --key)
      [ -n "${2:-}" ] || { ui_error "--key needs a public key"; exit 1; }
      EXTRA_KEYS+=("$2"); shift ;;
    -h|--help) ui_info "$USAGE"; exit 0 ;;
    -*) ui_error "unknown option: $1"; ui_error "$USAGE"; exit 1 ;;
    *)  [ -z "$NAME" ] || { ui_error "$USAGE"; exit 1; }; NAME="$1" ;;
  esac
  shift
done
[ -n "$NAME" ] || { ui_error "$USAGE"; exit 1; }
# AllowUsers root plus PermitRootLogin no would admit nobody.
[ "$(id -u)" != 0 ] || die "run as your own user, not root: it uses sudo where needed"
has sudo || die "sudo is not installed"
# Becomes the Tailscale machine name, which is a DNS label.
case "$NAME" in
  *[!a-z0-9-]*|-*) ui_error "name must be lowercase letters, digits and dashes"; exit 1 ;;
esac

KEYS="$HOME/.ssh/authorized_keys"
HOSTS_FILE="$HOME/.ssh/config.d/10-servers.conf"
# 01- so it sorts before distro drop-ins: sshd keeps the FIRST value it reads,
# and Ubuntu's 50-cloud-init.conf turns PasswordAuthentication back on.
DROPIN=/etc/ssh/sshd_config.d/01-dotfiles.conf
TS_MAC=/Applications/Tailscale.app/Contents/MacOS/Tailscale
# The system sshd the service runs, never PATH: a Homebrew openssh earlier on
# PATH reads /opt/homebrew/etc/ssh, so checks against it test the wrong config.
SSHD=/usr/sbin/sshd

_keys() {
  ui_section "authorized_keys"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  touch "$KEYS" && chmod 600 "$KEYS"

  local sock key added=0

  # ssh-keygen -l rejects anything that is not a public key, so a mispaste
  # (a private key, half a line) never lands in authorized_keys.
  # The ${a[@]+...} form because macOS bash 3.2 calls an empty array unbound
  # under set -u.
  for key in ${EXTRA_KEYS[@]+"${EXTRA_KEYS[@]}"}; do
    if ! printf '%s\n' "$key" | ssh-keygen -l -f - >/dev/null 2>&1; then
      ui_error "--key is not a valid public key: ${key:0:40}..."
      return 1
    fi
    grep -qxF "$key" "$KEYS" || { printf '%s\n' "$key" >> "$KEYS"; added=$((added + 1)); }
  done

  sock="$(awk '/IdentityAgent/ { print $2 }' "$HOME/.ssh/config.d/00-agent.conf" 2>/dev/null)"
  if [ -n "$sock" ] && [ -S "$sock" ]; then
    while IFS= read -r key; do
      case "$key" in ssh-*|ecdsa-*|sk-*) ;; *) continue ;; esac
      grep -qxF "$key" "$KEYS" || { printf '%s\n' "$key" >> "$KEYS"; added=$((added + 1)); }
    done < <(SSH_AUTH_SOCK="$sock" ssh-add -L 2>/dev/null)
  fi
  ui_info "$added added, $(grep -c '^[a-z]' "$KEYS") authorized"

  # Turning passwords off with no key in place locks everyone out.
  if ! grep -q '^[a-z]' "$KEYS"; then
    ui_error "no keys: unlock Bitwarden (Settings > Allow SSH agent), or re-run"
    ui_error "with --key \"\$(cat ~/.ssh/id_ed25519.pub)\" from the machine you connect from"
    return 1
  fi
}

_sshd_install() {
  [ -x "$SSHD" ] && return 0
  ui_section "openssh-server"
  case "$PKG" in
    pacman) sysinstall openssh ;;
    *)      sysinstall openssh-server ;;
  esac || return 1
}

_lockdown() {
  ui_section "sshd: keys only, only $USER"
  # Older macOS, RHEL 8 and Alpine ship no drop-in include. Add one at the
  # top, since sshd keeps the first value it reads. sudo grep: Fedora and RHEL
  # make sshd_config root-only. No file at all is openSUSE, whose vendor copy
  # in /usr/etc/ssh already includes the drop-ins.
  if [ -f /etc/ssh/sshd_config ] &&
     ! sudo grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    { echo "Include /etc/ssh/sshd_config.d/*.conf"; sudo cat /etc/ssh/sshd_config.bak; } \
      | sudo tee /etc/ssh/sshd_config >/dev/null
    ui_info "added the sshd_config.d include, original at /etc/ssh/sshd_config.bak"
  fi
  sudo mkdir -p /etc/ssh/sshd_config.d
  # ChallengeResponseAuthentication, not KbdInteractiveAuthentication: the new
  # name is OpenSSH 8.7+, and older sshd refuses a file with an unknown keyword.
  printf '%s\n' \
    "# Written by dotfiles lib/sshable.sh. Delete this file to undo." \
    "PasswordAuthentication no" \
    "ChallengeResponseAuthentication no" \
    "PermitRootLogin no" \
    "AllowUsers $USER" | sudo tee "$DROPIN" >/dev/null

  # sshd -t refuses to run without host keys, and Arch, Fedora and Alpine
  # only make them on the service's first start. -A creates only missing ones.
  sudo /usr/bin/ssh-keygen -A >/dev/null
  # Debian's sshd -t needs this, and only systemd creates it, on first start.
  is_linux && sudo mkdir -p /run/sshd
  # A drop-in sshd cannot parse stops it accepting anyone, so back it out.
  if ! sudo "$SSHD" -t; then
    sudo rm -f "$DROPIN"
    ui_error "sshd rejected the config, removed $DROPIN"
    return 1
  fi
  # The effective value, not the file: an earlier drop-in could still win.
  # Captured first: grep -q quits at the match, sshd -T dies of SIGPIPE, and
  # pipefail turns that into a failure whenever the output runs long.
  local effective
  effective="$(sudo "$SSHD" -T 2>/dev/null)"
  # -i: OpenSSH 10.5+ prints keywords CamelCase, older ones lowercase.
  if ! grep -qix 'passwordauthentication no' <<<"$effective"; then
    ui_error "passwords still on: another file in /etc/ssh/sshd_config.d sets it first"
    return 1
  fi
  ui_info "passwords and root login off"
}

_sshd_on() {
  ui_section "sshd on"
  if is_macos; then
    # Same as System Settings > Sharing > Remote Login. `systemsetup
    # -setremotelogin` does this too but needs Full Disk Access for the
    # terminal. bootstrap fails harmlessly when it is already loaded.
    sudo launchctl enable system/com.openssh.sshd
    sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    # When "Only these users" is set in Sharing, this group is that list.
    if dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1 &&
       ! dsmemberutil checkmembership -U "$USER" -G com.apple.access_ssh | grep -q 'is a member'; then
      sudo dseditgroup -o edit -a "$USER" -t user com.apple.access_ssh
    fi
  elif [ -d /run/systemd/system ]; then
    # Debian and Ubuntu call it ssh, everyone else sshd. Ubuntu 22.10+ starts
    # it from ssh.socket. try-reload-or-restart makes an already running sshd
    # read the new drop-in and leaves a stopped one alone.
    local unit=sshd
    systemctl cat ssh.service >/dev/null 2>&1 && unit=ssh
    if systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
      sudo systemctl enable --now ssh.socket || return 1
    else
      sudo systemctl enable --now "$unit" || return 1
    fi
    sudo systemctl try-reload-or-restart "$unit"
  elif has rc-service; then
    sudo rc-update add sshd default >/dev/null
    sudo rc-service sshd start
    sudo rc-service sshd reload
  else
    ui_error "no systemd or OpenRC (WSL without systemd?): start sshd by hand"
    return 1
  fi
  # bash's /dev/tcp, not nc: minimal Debian and Fedora images have no nc.
  if (exec 3<>/dev/tcp/127.0.0.1/22) 2>/dev/null; then
    ui_info "listening on 22"
  else
    ui_error "nothing listening on 22"
    return 1
  fi
}

_awake() {
  is_macos || return 0
  ui_section "power"
  # -c is on the charger only, so a laptop still sleeps on battery.
  # autorestart brings a desktop back after a power cut.
  sudo pmset -c sleep 0
  sudo pmset -a womp 1 autorestart 1
  ui_info "no sleep on power, wake for network, restart after power loss"
  if fdesetup status 2>/dev/null | grep -q 'On'; then
    ui_warn "FileVault is on: after a reboot, test SSH before you rely on it"
  fi
}

_tailscale() {
  ui_section "Tailscale as $NAME"
  local ts
  if is_macos; then
    # The app, from brew, the App Store or the .pkg, all land in the same
    # place. A bare `tailscale` is the open-source daemon from the formula.
    if [ ! -x "$TS_MAC" ] && ! has tailscale; then
      load_brew >/dev/null 2>&1 || { ui_error "no Homebrew: install Tailscale from tailscale.com/download, then re-run"; return 1; }
      brew install --cask tailscale-app || return 1
    fi
    if [ -x "$TS_MAC" ]; then ts="$TS_MAC"; else ts=tailscale; fi
    "$ts" status >/dev/null 2>&1 || { [ "$ts" = "$TS_MAC" ] && open -a Tailscale; }
  else
    if ! has tailscale; then
      has curl || { ui_error "curl is not installed"; return 1; }
      curl -fsSL https://tailscale.com/install.sh | sh || return 1
    fi
    ts=tailscale
    # Prints a login URL and waits for it.
    "$ts" status >/dev/null 2>&1 || sudo tailscale up
  fi

  # The macOS app signs in through its own window, so wait on the person.
  while ! "$ts" status >/dev/null 2>&1; do
    ui_info "sign in to Tailscale, then press Enter (Ctrl-C to stop)"
    read -r _ || return 1
  done

  if [ "$ts" = "$TS_MAC" ]; then "$ts" set --hostname="$NAME"; else sudo tailscale set --hostname="$NAME"; fi
  ui_info "tailnet address: $("$ts" ip -4 2>/dev/null | head -n 1)"
}

_keys          || exit 1
sudo -v        || exit 1
_sshd_install  || exit 1
_lockdown      || exit 1
_sshd_on       || exit 1
_awake
_tailscale     || exit 1

# The block for ~/.ssh/config.d/10-servers.conf on every other machine, and
# for the "dotfiles: ssh servers" Bitwarden note.
_block() {
  printf '\nHost %s\n' "$NAME"
  printf '\t# Tailscale MagicDNS name. Without MagicDNS, use: tailscale ip -4 %s\n' "$NAME"
  printf '\tHostName %s\n\tUser %s\n' "$NAME" "$USER"

  # .local names need mDNS: built into macOS, avahi on Linux.
  # uname -n, not hostname -s: Arch ships no hostname command by default.
  local lan
  if is_macos; then
    lan="$(scutil --get LocalHostName 2>/dev/null || uname -n | cut -d. -f1)"
  elif pgrep -x avahi-daemon >/dev/null 2>&1; then
    lan="$(uname -n | cut -d. -f1)"
  else
    return 0
  fi
  printf '\nHost %s-lan\n' "$NAME"
  printf '\t# Same network only, for when Tailscale is off.\n'
  printf '\tHostName %s.local\n\tUser %s\n' "$lan" "$USER"
}

# Same guard as the ssh install step: a file in config.d that will not parse
# breaks ssh for every host, so back the append out.
_save() {
  ui_section "10-servers.conf"
  if [ -f "$HOSTS_FILE" ] && grep -qE "^[[:space:]]*Host[[:space:]]+$NAME([[:space:]]|$)" "$HOSTS_FILE"; then
    ui_info "Host $NAME already there, left alone"
    return 0
  fi
  local had=0
  [ -f "$HOSTS_FILE" ] && { cp "$HOSTS_FILE" "$HOSTS_FILE.bak"; had=1; }
  _block >> "$HOSTS_FILE"
  chmod 600 "$HOSTS_FILE"
  if ! ssh -G "$NAME" >/dev/null 2>&1; then
    if [ "$had" = 1 ]; then mv "$HOSTS_FILE.bak" "$HOSTS_FILE"; else rm -f "$HOSTS_FILE"; fi
    ui_error "ssh config would not parse, append undone"
    return 1
  fi
  if [ "$had" = 1 ]; then ui_info "appended, previous version at $HOSTS_FILE.bak"; else ui_info "created"; fi
}

[ "$SAVE" = 1 ] && _save

ui_section "Add to 10-servers.conf and the Bitwarden note (dots hosts, dots backup)"
_block
printf '\n'
