# Shared across every machine. Machine-specific config goes in ~/.zshrc.local.

# Homebrew first, everything below comes from it.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Where the Claude Code and Zed installers drop their binaries.
export PATH="$HOME/.local/bin:$PATH"

# --wait so git and dots block until the buffer closes.
command -v zed >/dev/null && export EDITOR="zed --wait"

export ZSH="$HOME/.oh-my-zsh"

plugins=(
  git gh
  laravel artisan composer
  npm node nvm
  docker docker-compose
  brew macos vscode
  history command-not-found colorize cp battery aliases
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

fpath+=${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src

source $ZSH/oh-my-zsh.sh

# The laravel plugin aliases artisan to `php artisan`, which shadows the smarter
# artisan plugin function (sail/vendor detection + completion). Drop the alias so
# the function wins. `pa` already covers plain `php artisan`.
unalias artisan 2>/dev/null


# Aliases

alias ls='eza'
alias ll='eza -la'
alias llh='eza -la --git'
alias cat='bat'

alias gs='git status'
alias gcm='git commit'

alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias su='sail up -d'
alias sdev='sail npm run dev'
alias sbd='sail npm run build'
alias sa='sail artisan'
alias sc='sail composer'
alias srs='sail root-shell'
alias saoc='sa optimize:clear'
alias st='sail test -p'
alias stc='sail test --coverage -p'
alias sthtml='sail test --coverage-html -p'
alias shs='sail horizon:status'
alias shfr='sail horizon:forget --all'
alias shc='sail horizon:clear'

alias pa='php artisan'
alias pam='php artisan migrate'
alias paoc='php artisan optimize:clear'
alias pint='./vendor/bin/pint'
alias pest='./vendor/bin/pest'
alias patc='pest --parallel --bail --coverage --recreate-databases --tia'
alias patr='pest --bail --profile'

alias nd='npm run dev'
alias nbd='npm run build'
alias cpd='composer dump-autoload'
alias cpr='composer require'

alias dcp='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'

alias reloadcli='source ~/.zshrc'


# Functions

# These were aliases in older setups. Drop any stale alias first so re-sourcing
# (reloadcli) can redefine them as functions instead of erroring.
unalias rmlogs rmlp zshconfig 2>/dev/null

# paints the whole thing red.
zshconfig() { ${=EDITOR:-vi} ~/.zshrc }

rmlogs() {
  local log_path="${1:-storage/logs/laravel.log}"
  : > "$log_path" && echo "Log file cleared: $log_path"
}

rmlp() {
  local pattern="${1:-laravel}" log_dir="storage/logs" log_file found=0

  [[ -d "$log_dir" ]] || { echo "Error: $log_dir does not exist" >&2; return 1; }

  for log_file in "$log_dir/$pattern"*(N); do
    [[ -f "$log_file" ]] || continue
    : > "$log_file" && echo "Cleared log file: $log_file"
    found=1
  done

  (( found )) || echo "No matching log files found with pattern: $pattern"
}

# yazi: `y` opens it and cds to wherever you quit. command cat / builtin cd
# because cat and cd are aliased.
y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  cwd="$(command cat -- "$tmp")"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}


# dots: open or run anything in the dotfiles repo

export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Projects/dotfiles}"

dots() {
  local repo="$DOTFILES_DIR" cmd="${1:-cd}"
  # zsh does not word-split unquoted scalars, so a scalar ed="zed --wait" would
  # be looked up as one command name. ${=...} splits it into an array instead.
  local -a ed=( ${=EDITOR:-vi} )
  [[ -d "$repo" ]] || { print -u2 "dots: $repo not found"; return 1; }
  shift 2>/dev/null

  case "$cmd" in
    cd)                cd "$repo" ;;
    brew|pkg)          $ed "$repo/Brewfile" ;;
    cask|mac|apps)     $ed "$repo/Brewfile.macos" ;;
    zsh|rc)            $ed "$repo/home/.zshrc" ;;
    local|secrets)     $ed "$HOME/.zshrc.local" ;;
    claude|plugins)    $ed "$repo/claude/plugins.txt" ;;
    starship|prompt)   $ed "$repo/home/.config/starship.toml" ;;
    ghostty|term)      $ed "$repo/home/.config/ghostty/config" ;;
    atuin)             $ed "$repo/home/.config/atuin/config.toml" ;;
    eza)               $ed "$repo/home/.config/eza/theme.yml" ;;
    zed|editor)        $ed "$repo/home/.config/zed/settings.json" ;;
    keymap)            $ed "$repo/home/.config/zed/keymap.json" ;;
    tasks)             $ed "$repo/home/.config/zed/tasks.json" ;;
    snippets)          cd "$repo/home/.config/zed/snippets" && $ed . ;;
    steps)             $ed "$repo/lib/steps.d" ;;
    readme)            $ed "$repo/README.md" ;;

    install|run)       "$repo/install.sh" "$@" ;;
    link)              "$repo/install.sh" link ;;
    log)               ${=PAGER:-less} "${TMPDIR:-/tmp}/dotfiles-install.log" ;;
    status|st)         git -C "$repo" status --short ;;
    diff)              git -C "$repo" diff ;;

    pull|sync)         git -C "$repo" pull --ff-only && "$repo/install.sh" link ;;
    push)              git -C "$repo" add -A && git -C "$repo" commit && git -C "$repo" push ;;

    help|-h|--help|*)
      print -r -- "dots, managing $repo
  (none)      cd to the repo          steps       add/edit an install step
  brew        CLI tools               readme      the docs
  cask        macOS apps + fonts
  zsh         shared .zshrc           install     run the installer
  local       secrets, per-machine    link        re-link dotfiles only
  claude      marketplaces/plugins    log         last install log
  starship    prompt                  status      git status
  ghostty     terminal                diff        git diff
  atuin       shell history           pull        git pull + re-link
  eza         ls colours              push        add + commit + push
  zed         Zed settings            keymap      Zed keybindings
  tasks       Zed tasks               snippets    Zed snippets"
      ;;
  esac
}

_dots() {
  compadd cd brew pkg cask mac apps zsh rc local secrets claude plugins \
          starship prompt ghostty term atuin eza zed editor keymap tasks \
          snippets steps readme \
          install run link log status st diff pull sync push help
}
compdef _dots dots 2>/dev/null


command -v starship >/dev/null && eval "$(starship init zsh)"
command -v fzf      >/dev/null && source <(fzf --zsh)
command -v atuin    >/dev/null && eval "$(atuin init zsh)"

export EZA_CONFIG_DIR="$HOME/.config/eza"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# zoxide last, it warns if anything re-runs compinit after its init.
command -v zoxide >/dev/null && eval "$(zoxide init zsh)" && alias cd='z'
