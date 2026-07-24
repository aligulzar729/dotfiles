# Screen output. Nothing in here installs anything.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  UI_TTY=1
else
  UI_TTY=0
fi

if [ "$UI_TTY" = 1 ]; then
  C_OFF=$'\033[0m';  C_DIM=$'\033[2m';   C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m';  C_YLW=$'\033[33m'
  C_BLU=$'\033[34m'; C_MAG=$'\033[35m';  C_CYN=$'\033[36m'
else
  C_OFF=; C_DIM=; C_BOLD=; C_RED=; C_GRN=; C_YLW=; C_BLU=; C_MAG=; C_CYN=
fi

UI_OK="✓"; UI_SKIP="·"; UI_FAIL="✗"; UI_WARN="!"

ui_cursor_hide() { [ "$UI_TTY" = 1 ] && printf '\033[?25l'; return 0; }
ui_cursor_show() { [ "$UI_TTY" = 1 ] && printf '\033[?25h'; return 0; }
ui_clear_line()  { [ "$UI_TTY" = 1 ] && printf '\r\033[2K'; return 0; }

ui_banner() {
  printf '\n%s┌───────────────────────────────────────────────┐%s\n' "$C_BLU" "$C_OFF"
  printf '%s│%s  %sdotfiles%s  ·  one machine setup, everywhere  %s│%s\n' \
    "$C_BLU" "$C_OFF" "$C_BOLD" "$C_OFF" "$C_BLU" "$C_OFF"
  printf '%s└───────────────────────────────────────────────┘%s\n\n' "$C_BLU" "$C_OFF"
}

ui_meta()    { printf '  %s%-10s%s %s\n' "$C_DIM" "$1" "$C_OFF" "$2"; }
ui_section() { printf '\n%s%s%s\n' "$C_BOLD$C_MAG" "$1" "$C_OFF"; }
ui_info()    { printf '  %s%s%s\n' "$C_DIM" "$1" "$C_OFF"; }
ui_warn()    { printf '  %s%s%s %s\n' "$C_YLW" "$UI_WARN" "$C_OFF" "$1" >&2; }
ui_error()   { printf '  %s%s%s %s\n' "$C_RED" "$UI_FAIL" "$C_OFF" "$1" >&2; }
ui_note()    { printf '    %s↳ %s%s\n' "$C_DIM" "$1" "$C_OFF"; }

# Array, not a string. bash 3.2 substring indexing on multibyte glyphs is
# locale dependent and returns garbage.
UI_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
_ui_spin_pid=""

ui_spin_start() {
  local msg="$1"
  if [ "${VERBOSE:-0}" = 1 ]; then
    printf '  %s%s %s%s\n' "$C_DIM" "$UI_SKIP" "$msg" "$C_OFF"
    return 0
  fi
  [ "$UI_TTY" != 1 ] && return 0
  ui_cursor_hide
  (
    local i=0
    while :; do
      i=$(( (i + 1) % ${#UI_FRAMES[@]} ))
      printf '\r  %s%s%s %s' "$C_CYN" "${UI_FRAMES[$i]}" "$C_OFF" "$msg"
      sleep 0.08
    done
  ) &
  _ui_spin_pid=$!
}

ui_spin_stop() {
  [ -n "$_ui_spin_pid" ] || return 0
  kill "$_ui_spin_pid" 2>/dev/null || true
  wait "$_ui_spin_pid" 2>/dev/null || true
  _ui_spin_pid=""
  ui_clear_line
  ui_cursor_show
}

# ui_result ok|skip|fail <label> [detail]
ui_result() {
  local state="$1" label="$2" detail="${3:-}" icon color
  case "$state" in
    ok)   icon="$UI_OK";   color="$C_GRN" ;;
    skip) icon="$UI_SKIP"; color="$C_DIM" ;;
    fail) icon="$UI_FAIL"; color="$C_RED" ;;
  esac
  if [ "$state" = skip ]; then
    printf '  %s%s %s%s\n' "$color" "$icon" "$label" "$C_OFF"
  else
    printf '  %s%s%s %s\n' "$color" "$icon" "$C_OFF" "$label"
  fi
  [ -n "$detail" ] && ui_note "$detail"
  return 0
}

ui_summary() {
  local ok="$1" skipped="$2" failed="$3" logfile="$4"
  printf '\n%s────────────────────────────────────────────────%s\n' "$C_DIM" "$C_OFF"
  printf '  %s%s %s done%s   %s%s %s unchanged%s' \
    "$C_GRN" "$UI_OK" "$ok" "$C_OFF" "$C_DIM" "$UI_SKIP" "$skipped" "$C_OFF"
  if [ "$failed" -gt 0 ]; then
    printf '   %s%s %s failed%s\n' "$C_RED" "$UI_FAIL" "$failed" "$C_OFF"
    printf '  %slog: %s%s\n' "$C_DIM" "$logfile" "$C_OFF"
  else
    printf '\n'
  fi
}

# Draws to stderr, echoes the chosen indices to stdout.
ui_select() {
  local title="$1"; shift
  local items=("$@")
  local n=${#items[@]} cur=0 i key rest
  local checked=()
  for ((i = 0; i < n; i++)); do checked[i]=1; done

  if [ "$UI_TTY" != 1 ]; then
    for ((i = 0; i < n; i++)); do printf '%s ' "$i"; done
    return 0
  fi

  printf '%s%s%s\n' "$C_BOLD" "$title" "$C_OFF" >&2
  printf '%s  ↑↓ move · space toggle · a all · n none · enter run · q quit%s\n\n' \
    "$C_DIM" "$C_OFF" >&2

  ui_cursor_hide
  while :; do
    for ((i = 0; i < n; i++)); do
      local mark pointer
      [ "${checked[$i]}" = 1 ] && mark="${C_GRN}◉${C_OFF}" || mark="${C_DIM}◯${C_OFF}"
      if [ "$i" = "$cur" ]; then
        pointer="${C_CYN}❯${C_OFF}"
        printf '  %s %s %s%s%s\n' "$pointer" "$mark" "$C_BOLD" "${items[$i]}" "$C_OFF" >&2
      else
        printf '    %s %s\n' "$mark" "${items[$i]}" >&2
      fi
    done

    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.05 rest || rest=""
        case "$rest" in
          '[A') cur=$(( (cur - 1 + n) % n )) ;;
          '[B') cur=$(( (cur + 1) % n )) ;;
        esac
        ;;
      k) cur=$(( (cur - 1 + n) % n )) ;;
      j) cur=$(( (cur + 1) % n )) ;;
      ' ') [ "${checked[$cur]}" = 1 ] && checked[$cur]=0 || checked[$cur]=1 ;;
      a) for ((i = 0; i < n; i++)); do checked[i]=1; done ;;
      n) for ((i = 0; i < n; i++)); do checked[i]=0; done ;;
      q) ui_cursor_show; printf '\n' >&2; exit 0 ;;
      '') break ;;
    esac

    printf '\033[%dA' "$n" >&2
  done
  ui_cursor_show
  printf '\n' >&2

  for ((i = 0; i < n; i++)); do
    [ "${checked[$i]}" = 1 ] && printf '%s ' "$i"
  done
  return 0
}

ui_confirm() {
  [ "${ASSUME_YES:-0}" = 1 ] && return 0
  [ "$UI_TTY" != 1 ] && return 0
  local reply
  printf '  %s?%s %s %s[Y/n]%s ' "$C_YLW" "$C_OFF" "$1" "$C_DIM" "$C_OFF"
  IFS= read -r reply
  case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}
