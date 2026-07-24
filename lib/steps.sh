# Loads the step definitions from steps.d and builds the ordered step list.
# Each domain file calls `register <name> <desc>` then defines step_<name>.
# Source order here is run order, so dependencies stay obvious.

STEP_NAMES=()
STEP_DESCS=()

register() {
  STEP_NAMES+=("$1")
  STEP_DESCS+=("$2")
}

step_desc() {
  local i
  for i in "${!STEP_NAMES[@]}"; do
    [ "${STEP_NAMES[$i]}" = "$1" ] && { printf '%s\n' "${STEP_DESCS[$i]}"; return; }
  done
}

for _domain in system apps shell dotfiles claude; do
  . "$DOTFILES/lib/steps.d/$_domain.sh"
done
unset _domain

STEPS="${STEP_NAMES[*]}"
