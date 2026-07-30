#!/usr/bin/env bash
#
#   ./install.sh                pick steps interactively
#   ./install.sh --all          run everything
#   ./install.sh link claude    run named steps
#   ./install.sh --verbose zsh  show output instead of logging it

# Re-exec under real bash. Launching via `sh install.sh` (or macOS /bin/sh,
# which is bash in POSIX mode) disables arrays and process substitution, which
# this script relies on. One guarded exec sidesteps all of that.
if [ -z "${DOTFILES_REEXEC:-}" ]; then
  export DOTFILES_REEXEC=1
  exec bash "$0" "$@"
fi

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$DOTFILES/lib/ui.sh"
. "$DOTFILES/lib/core.sh"
. "$DOTFILES/lib/steps.sh"

trap 'ui_spin_stop; ui_cursor_show' EXIT
# Separate from EXIT so Ctrl-C actually stops the run; the old shared handler
# returned and let the next step start.
trap 'ui_spin_stop; ui_cursor_show; exit 130' INT TERM

VERBOSE=0
ASSUME_YES=0
SELECTED=""

usage() {
  cat <<EOF
Usage: ./install.sh [options] [step...]

Options:
  -a, --all       run every step without prompting
  -l, --list      list available steps
  -v, --verbose   show command output instead of writing it to the log
  -y, --yes       answer yes to confirmations
  -h, --help      this message

Steps:
$(for s in $STEPS; do printf '  %-10s %s\n' "$s" "$(step_desc "$s")"; done)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--all)     SELECTED="$STEPS"; ASSUME_YES=1 ;;
    -l|--list)    for s in $STEPS; do printf '%-10s %s\n' "$s" "$(step_desc "$s")"; done; exit 0 ;;
    -v|--verbose) VERBOSE=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      case " $STEPS " in
        *" $1 "*) SELECTED="$SELECTED $1" ;;
        *) echo "unknown step: $1" >&2; usage >&2; exit 1 ;;
      esac
      ;;
  esac
  shift
done

detect_platform
# The re-exec above is a non-login, non-interactive bash: it reads no .zshrc,
# .zprofile or .bash_profile, so brew is only on PATH if the caller had it.
load_brew >/dev/null 2>&1 || true
ui_banner
ui_meta "platform" "$OS ($ARCH)"
ui_meta "packages" "${PKG:-homebrew only}"
ui_meta "dotfiles" "$DOTFILES"
ui_meta "log"      "$LOG_FILE"
printf '\n'

if [ -z "${SELECTED// /}" ]; then
  labels=()
  for s in $STEPS; do labels+=("$(printf '%-9s %s' "$s" "$(step_desc "$s")")"); done

  chosen="$(ui_select "Select what to install" "${labels[@]}")"

  i=0
  for s in $STEPS; do
    case " $chosen " in *" $i "*) SELECTED="$SELECTED $s" ;; esac
    i=$((i + 1))
  done
fi

if [ -z "${SELECTED// /}" ]; then
  ui_info "Nothing selected."
  exit 0
fi

for s in $SELECTED; do
  ui_section "$(step_desc "$s")"
  "step_$s"
done

ui_summary "$COUNT_OK" "$COUNT_SKIP" "$COUNT_FAIL" "$LOG_FILE"

if [ "$COUNT_FAIL" -gt 0 ]; then
  printf '\n'
  ui_warn "Some steps failed. Re-run them with --verbose, e.g. ./install.sh --verbose packages"
  exit 1
fi

printf '\n'
ui_info "Restart your terminal, or: exec zsh"
