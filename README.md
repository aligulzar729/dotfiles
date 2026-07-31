# dotfiles

Same shell setup on every machine. macOS, Linux, WSL.

```sh
git clone https://github.com/aligulzar729/dotfiles ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

That opens a picker. Take everything on a new box, one step on an old one.

```sh
./install.sh --all             # no prompts
./install.sh link claude       # named steps
./install.sh --verbose zsh     # stream output instead of logging it
./install.sh --list            # what the steps are
```

## How it works

`home/` mirrors your home directory and every file in it gets symlinked into
place. `~/.zshrc` is a link to `home/.zshrc`, so editing your shell config
edits the repo. Commit, push, pull on the other machine, done. No sync logic,
no copying.

Tools are installed from upstream: Homebrew formulae, the oh-my-zsh installer,
each plugin's git repo, Zed's own install script. Nothing is copied between
machines.

## What it installs

| | |
|---|---|
| Shell | zsh, oh-my-zsh, starship |
| History and nav | atuin, zoxide, fzf |
| Coreutils | eza, bat, ripgrep, fd |
| Extras | tealdeer, glow, yazi, ani-cli + ani-skip |
| Dev | git, gh, lazygit, git-delta, mailpit |
| Apps | Ghostty, Zed, Pika, VLC, GitHub Desktop Plus, JetBrainsMono Nerd Font |
| Configs | zsh, git (delta), ssh (template), starship, atuin, eza, ghostty, Zed |
| Claude Code | CLI, 14 marketplaces, 19 plugins, 25 skills (5 local, 20 from skills.txt) |
| omz plugins | zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search, zsh-completions, artisan |

## The dots command

Lives in `home/.zshrc`, so it exists wherever this repo lands. Tab completes.
On its own it cds to the repo, otherwise it opens whatever you need to edit.

```sh
dots brew        # add a CLI tool          dots install   # run the installer
dots cask        # add a macOS app         dots link      # re-link dotfiles only
dots zsh         # shared shell config     dots log       # last install log
dots local       # secrets, per-machine    dots status    # git status
dots claude      # marketplaces/plugins    dots diff      # git diff
dots starship    # prompt                  dots pull      # git pull + re-link
dots ghostty     # terminal                dots push      # add + commit + push
dots zed         # Zed settings            dots keymap    # Zed keybindings
dots tasks       # Zed tasks               dots snippets  # Zed snippets
dots atuin / eza / steps / readme / help
```

The usual loop:

```sh
dots brew                  # add a line, save
dots install packages      # apply
dots push                  # share it
```

Set `DOTFILES_DIR` in `~/.zshrc.local` if you clone somewhere else.

## Layout

```
install.sh              args, step picker, run, summary
lib/ui.sh               colors, spinner, picker, summary
lib/core.sh             platform detection, task runner, ensure_* helpers
lib/steps.sh            loader: sources steps.d, builds the ordered step list
lib/steps.d/
  system.sh             prereqs, homebrew, packages, fonts
  apps.sh               Ghostty, Zed, GitHub Desktop Plus
  shell.sh              oh-my-zsh + plugins, login shell
  dotfiles.sh           symlink home/ into ~
  claude.sh             Claude Code CLI, skills, plugins
Brewfile                CLI stack, all platforms
Brewfile.macos          casks and fonts
home/                   mirrors ~, everything in here gets symlinked
claude/plugins.txt      marketplace to plugin manifest
claude/skills.txt       third-party skills, installed with the skills CLI
claude/skills/          5 skills written here, each linked into ~/.claude/skills
```

Three layers, one job each. UI never installs, steps never print. Every action
goes through `task` in `core.sh`, which owns the spinner, the log, the counters
and the result line. A step is a list of `task "label" some_function` lines.

Steps live in `lib/steps.d/` grouped by domain. Each file registers its steps
with `register <name> <description>`, so the description sits next to the code.
`steps.sh` sources them in dependency order and that order is the run order.
Adding a domain is a new file plus its name in the `steps.sh` source loop.

## Adding something

| Want to add | Edit | Apply |
|---|---|---|
| A CLI tool | `dots brew` | `dots install packages` |
| A macOS app or font | `dots cask` | `dots install packages` |
| An omz plugin | `OMZ_PLUGINS` in `lib/steps.d/shell.sh` and `plugins=()` in `home/.zshrc` | `dots install zsh` |
| A dotfile | drop it in `home/` at its path relative to `~` | `dots link` |
| A Claude plugin | `dots claude` | `dots install claude` |
| A step | in the matching `lib/steps.d/*.sh`: `register`, then a `step_x` function | `dots install x` |
| A whole domain | new `lib/steps.d/<name>.sh`, add `<name>` to the loop in `lib/steps.sh` | `dots install ...` |

## Safety

Every step checks before it acts, so a second run reports `unchanged` instead
of redoing work. A real file in the way of a symlink is moved to `<name>.bak`,
never deleted. Secrets live in `~/.zshrc.local`, which is created from the
example on first run and gitignored. One failing task does not abort the run;
failures are counted and the log path is printed at the end.

## Windows

Use WSL2. The installer detects it, installs the whole CLI stack through Linux
Homebrew, and skips the desktop apps.

```powershell
wsl --install -d Ubuntu
```

Then inside WSL, same as any Linux box:

```sh
git clone <your-repo-url> ~/Projects/dotfiles
cd ~/Projects/dotfiles && ./install.sh --all
```

PowerShell, cmd, Git Bash, MSYS2 and Cygwin do not work. This is bash, it
relies on symlinks and a POSIX home, and Homebrew has no Windows build.

Desktop apps go on the Windows side:

- Ghostty has no official Windows build. Use Windows Terminal or WezTerm and
  run WSL inside it.
- Zed has a Windows build, check [zed.dev/download](https://zed.dev/download)
  for its status. It reads config from `%APPDATA%\Zed`, so copy
  `home/.config/zed/` there by hand.
- GitHub Desktop Plus, see
  [releases](https://github.com/pol-rivero/GitHub-Desktop-Plus/releases/latest).

Keep the repo on the Linux filesystem, not `/mnt/c`. Symlinks and permissions
misbehave across the Windows mount and this repo is all symlinks.

## Notes

- Skills split two ways. Anything written here lives in `claude/skills/` and is
  linked one by one into `~/.claude/skills`, so other skills already on the
  machine stay put; a real directory in the way is backed up to `<name>.bak`.
  Everything from someone else's repo is listed in `skills.txt` and installed
  with `npx skills`, so `npx skills update` pulls upstream fixes instead of this
  repo carrying a stale copy. `impeccable` and `ui-ux-pro-max` are neither, they
  are plugins from their own repos, carried by `plugins.txt`.
- Zed's config is symlinked file by file, so changing settings in the Zed UI
  edits the repo. If an update ever replaces a symlink with a real file, run
  `dots link`.
- Zed's `prompts/` is not versioned. It is an LMDB database with a lock file,
  git cannot merge it.
- `$EDITOR` is `zed --wait` when Zed is on PATH. Override in `~/.zshrc.local`.
- Installers that append to `~/.zshrc` (Laravel Herd does this on every update)
  write into the tracked file, because `~/.zshrc` is a symlink into this repo.
  Move what they added to `~/.zshrc.local` and `git checkout home/.zshrc`.
- Linux gets Ghostty from the distro repo where one exists (Arch, Fedora),
  otherwise the installer prints the download URL.
- Needs bash 3.2, so it runs on stock macOS.

## SSH

- Host config is shareable, private keys are not. Copy `home/.ssh/config.example`
  to `~/.ssh/config` and add your hosts; it then works in terminal, git, rsync,
  and Termius alike.
- `.gitignore` blocks `id_*`, `*.pem`, `*.key` etc. so a private key can never
  be committed by accident. `*.pub` and `config.example` stay tracked.
- Keys themselves belong in a password-manager SSH agent (1Password, or the
  KeePassXC/Strongbox agent), not in this repo. Point `IdentityAgent` at its
  socket in your ssh config.
