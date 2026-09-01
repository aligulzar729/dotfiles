#!/usr/bin/env bash
#
#   ./lib/backup.sh push     write the private files into Bitwarden
#   ./lib/backup.sh pull     restore them from Bitwarden
#   ./lib/backup.sh status   show what exists where, change nothing
#
# The files that identify you live only on disk, because the repo is public.
# Not an install step: it needs your vault password, and a password prompt
# inside task() is swallowed by the log.

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$DOTFILES/lib/ui.sh"

# label|path  - the note name in Bitwarden, and where the file lives.
ITEMS="
dotfiles: ssh servers|$HOME/.ssh/config.d/10-servers.conf
dotfiles: job-hunt profile|$DOTFILES/claude/skills/job-hunt/references/PROFILE.md
"

has() { command -v "$1" >/dev/null 2>&1; }

_need_bw() {
  has bw && return 0
  ui_error "the Bitwarden CLI is not installed"
  if [ "$(uname -s)" = Darwin ]; then
    ui_info "brew install bitwarden-cli"
  else
    ui_info "npm install -g @bitwarden/cli   (no Linux bottle exists)"
  fi
  return 1
}

# bw prints the session key on stdout and its prompt on stderr, so the prompt
# stays visible while the key is captured.
_session() {
  if [ -n "${BW_SESSION:-}" ] && bw --session "$BW_SESSION" status 2>/dev/null | grep -q '"unlocked"'; then
    printf '%s' "$BW_SESSION"
    return 0
  fi
  case "$(bw status 2>/dev/null)" in
    *unauthenticated*) ui_error "not logged in: bw login"; return 1 ;;
  esac
  bw unlock --raw
}

# bw has no "get by exact name", so search and match the name ourselves.
_item_id() {
  local session="$1" label="$2"
  bw --session "$session" list items --search "$label" 2>/dev/null \
    | python3 -c '
import json, sys
label = sys.argv[1]
try:
    items = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for item in items:
    if item.get("name") == label:
        print(item["id"])
        break
' "$label"
}

# python3 rather than jq, to avoid the extra dependency.
_encode_item() {
  local label="$1" file="$2" id="${3:-}"
  python3 -c '
import json, sys
label, path, item_id = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as fh:
    body = fh.read()
item = {
    "type": 2,
    "name": label,
    "notes": body,
    "secureNote": {"type": 0},
    "favorite": False,
}
if item_id:
    item["id"] = item_id
print(json.dumps(item))
' "$label" "$file" "$id" | bw encode
}

cmd_push() {
  local session label file id encoded
  session="$(_session)" || return 1

  while IFS='|' read -r label file; do
    [ -z "$label" ] && continue
    if [ ! -f "$file" ]; then
      ui_warn "$label: $file does not exist, skipped"
      continue
    fi
    id="$(_item_id "$session" "$label")"
    encoded="$(_encode_item "$label" "$file" "$id")"
    if [ -n "$id" ]; then
      if printf '%s' "$encoded" | bw --session "$session" edit item "$id" >/dev/null 2>&1; then
        ui_info "updated  $label  ($(wc -l < "$file" | tr -d ' ') lines)"
      else
        ui_error "failed to update $label"
      fi
    else
      if printf '%s' "$encoded" | bw --session "$session" create item >/dev/null 2>&1; then
        ui_info "created  $label"
      else
        ui_error "failed to create $label"
      fi
    fi
  done <<EOF
$ITEMS
EOF
  bw --session "$session" sync >/dev/null 2>&1 || true
}

cmd_pull() {
  local session label file id body
  session="$(_session)" || return 1
  bw --session "$session" sync >/dev/null 2>&1 || true

  while IFS='|' read -r label file; do
    [ -z "$label" ] && continue
    id="$(_item_id "$session" "$label")"
    if [ -z "$id" ]; then
      ui_warn "$label: not in the vault yet, run push first"
      continue
    fi
    body="$(bw --session "$session" get notes "$id" 2>/dev/null)"
    if [ -z "$body" ]; then
      ui_warn "$label: note is empty, refusing to overwrite $file"
      continue
    fi
    # The local copy may be the newer one.
    if [ -f "$file" ] && ! printf '%s\n' "$body" | diff -q - "$file" >/dev/null 2>&1; then
      cp "$file" "$file.bak"
      ui_info "kept your version at $file.bak"
    fi
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$body" > "$file"
    chmod 600 "$file"
    ui_info "restored $label -> $file"
  done <<EOF
$ITEMS
EOF
}

cmd_status() {
  local session label file id
  session="$(_session)" || return 1
  printf '\n'
  while IFS='|' read -r label file; do
    [ -z "$label" ] && continue
    id="$(_item_id "$session" "$label")"
    printf '  %-28s local:%-9s vault:%s\n' \
      "$label" \
      "$([ -f "$file" ] && echo yes || echo MISSING)" \
      "$([ -n "$id" ] && echo yes || echo MISSING)"
  done <<EOF
$ITEMS
EOF
  printf '\n'
}

_need_bw || exit 1

case "${1:-status}" in
  push)   cmd_push ;;
  pull)   cmd_pull ;;
  status) cmd_status ;;
  *)      ui_error "usage: backup.sh push|pull|status"; exit 1 ;;
esac
