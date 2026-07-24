# Platform detection, the task runner, and the helpers steps are built from.

_tmpdir="${TMPDIR:-/tmp}"; _tmpdir="${_tmpdir%/}"
LOG_FILE="${LOG_FILE:-$_tmpdir/dotfiles-install.log}"
: > "$LOG_FILE"

COUNT_OK=0; COUNT_SKIP=0; COUNT_FAIL=0

has() { command -v "$1" >/dev/null 2>&1; }
die() { ui_error "$1"; exit 1; }

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)
      if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then OS=wsl; else OS=linux; fi
      ;;
    *) die "unsupported platform: $(uname -s)" ;;
  esac

  ARCH="$(uname -m)"
  HAS_GUI=1; [ "$OS" = wsl ] && HAS_GUI=0

  PKG=""
  local p
  for p in apt-get dnf pacman zypper apk; do
    has "$p" && { PKG="$p"; break; }
  done
}

is_macos() { [ "$OS" = macos ]; }
is_linux() { [ "$OS" = linux ] || [ "$OS" = wsl ]; }
is_wsl()   { [ "$OS" = wsl ]; }

# task <label> <function> [args...]
#
# The function is called, not piped. Redirecting a function call keeps it in
# this shell, so task_skip set inside it is visible here. A pipe would push it
# into a subshell and lose the state.
task() {
  local label="$1"; shift
  TASK_STATE=ok
  TASK_DETAIL=""

  ui_spin_start "$label"
  if [ "${VERBOSE:-0}" = 1 ]; then
    if "$@"; then :; else TASK_STATE=fail; fi
  else
    if "$@" >>"$LOG_FILE" 2>&1; then :; else TASK_STATE=fail; fi
  fi
  ui_spin_stop

  ui_result "$TASK_STATE" "$label" "$TASK_DETAIL"

  case "$TASK_STATE" in
    ok)   COUNT_OK=$((COUNT_OK + 1)) ;;
    skip) COUNT_SKIP=$((COUNT_SKIP + 1)) ;;
    fail) COUNT_FAIL=$((COUNT_FAIL + 1)); ui_note "see $LOG_FILE" ;;
  esac
  return 0
}

task_skip() { TASK_STATE=skip; TASK_DETAIL="${1:-}"; }
task_note() { TASK_DETAIL="${1:-}"; }

ensure_link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    task_skip "already linked"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up $dst -> $dst.bak"
  fi
  ln -sfn "$src" "$dst"
}

ensure_repo() {
  local dir="$1" url="$2" before after
  if [ -d "$dir/.git" ]; then
    before="$(git -C "$dir" rev-parse HEAD)"
    git -C "$dir" pull --quiet --ff-only || true
    after="$(git -C "$dir" rev-parse HEAD)"
    [ "$before" = "$after" ] && task_skip "already cloned" || task_note "updated"
    return 0
  fi
  rm -rf "$dir"
  git clone --depth 1 --quiet "$url" "$dir"
}

sysinstall() {
  case "$PKG" in
    apt-get) sudo apt-get update -qq && sudo apt-get install -y "$@" ;;
    dnf)     sudo dnf install -y "$@" ;;
    pacman)  sudo pacman -Sy --needed --noconfirm "$@" ;;
    zypper)  sudo zypper install -y "$@" ;;
    apk)     sudo apk add "$@" ;;
    *)       echo "no known package manager; install manually: $*"; return 1 ;;
  esac
}

load_brew() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew \
                   /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done
  has brew
}
