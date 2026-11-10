# Gaudi

[![tests](https://github.com/g-udi/gaudi/actions/workflows/tests.yml/badge.svg)](https://github.com/g-udi/gaudi/actions/workflows/tests.yml)

### _Gaudi: Craft Your Perfect Dev Environment_

 🏗️ Automate your machine setup
 🎨 Customize with templates
 🚀 From fresh install to fully equipped in minutes

As a developer or tech enthusiast, you have probably experienced the friction of setting up a new machine. Whether it is a fresh operating system install or a brand-new device, the process of reinstalling your go-to applications, configuring development environments, and getting everything to run smoothly can feel like a tedious chore. That is why I created [**Gaudi**](https://github.com/g-udi/gaudi): a tool designed to make setting up a new machine efficient, consistent, and repeatable.

```text
$ gaudi setup

[INFO] Detected OS: osx
[INFO] Detected shell: zsh

Brewfile: Applications (~/.gaudi/templates/lists/apps.Brewfile)
Desktop applications installed as Homebrew casks
Install this Brewfile? [y/N] y
Install everything in Applications? [Y/n] n

raycast (cask)
Description: Launcher and productivity tool
Install raycast? [y/N] y

kitty (cask)
Description: GPU-based terminal emulator
Install kitty? [y/N] n
...
Show Finder path bar [y/N] y
[OK] Gaudi setup finished
```

## The Problem: Time-Consuming Setup

Anyone who has had to reconfigure a new system from scratch understands the pain. You are faced with hours of:

- Installing software and tools such as [Homebrew](https://brew.sh/), [npm](https://www.npmjs.com/), [mas](https://github.com/mas-cli/mas), `apt`, and others.
- Customizing system preferences.
- Setting up your favorite applications.
- Re-configuring settings to match your old system.

It is a repetitive, manual process, and there is always a chance you will forget one or two critical steps, leaving your environment not quite right. Multiply that by each new device, and you are looking at a major time sink.

Gaudi is a Bash-based command line tool that sets a machine up from a **templates** repository: [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile) for software, hooks, and configuration scripts.

The main motivation behind Gaudi is:

- Have a clean, reproducible way to set up a machine from scratch by installing all the software and packages needed.
- Capture a machine with `gaudi backup` and reproduce it on the next one.
- Share machine setups between users with [templates](https://github.com/g-udi/gaudi-templates).
- Keep the bootstrapper predictable while still installing cleanly for Bash, Zsh, Fish, and POSIX-style login shells.

> Note: Gaudi automates macOS, Debian/Ubuntu and Fedora. Other Linux families are detected and reported rather than guessed.

## Installation

Install Gaudi from the command line:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)"
```

The installer makes sure Git is available (on a fresh Mac it installs [Homebrew](https://brew.sh/), which brings the Xcode Command Line Tools), clones Gaudi into `~/.gaudi` and starts the setup. It works on the Bash 3.2 that ships with macOS; nothing needs to be installed first. On Linux it uses `sudo`, or runs the commands directly when you are already root (a container, a fresh server).

Setup flags go after a name for the script:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)" gaudi --yes --skip-ssh
```

You can also clone the repository manually and run setup:

```sh
git clone https://github.com/g-udi/gaudi.git ~/.gaudi
~/.gaudi/setup.sh
```

Safe smoke setup that does not install packages, clone templates, or change machine configuration:

```sh
~/.gaudi/setup.sh --yes --skip-prereqs --skip-templates --skip-software --skip-configs --skip-shell-helpers --skip-ssh --skip-cleanup
```

### Updating

Run the installer again. It fetches the latest Gaudi, keeps your templates, and reruns the setup; everything already installed is left alone. If you changed files inside `~/.gaudi`, the installer keeps your version and tells you so instead of overwriting it.

## What does Gaudi do?

Gaudi automates the setup path in separate, skippable stages:

- **Install the prerequisites for the OS**: OS detection is automatic. macOS, Debian/Ubuntu and Fedora have fully automated paths.
- **Configure SSH**: Offer to generate an SSH key when none exists (a key file or a key served by an agent), so private template repositories can be cloned.
- **Configure Gaudi templates**: Clone or update the templates repository.
- **Install shell helpers**: Suggest shell helpers such as [gaudi-shell](https://github.com/g-udi/gaudi-shell) or [oh-my-zsh](https://ohmyz.sh/).
- **Install software**: Install the [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile) from the templates with `brew bundle`, plus apt, dnf and gem lists.
- **Run configuration scripts**: Apply OS-specific or shared machine configuration scripts from templates.
- **Restore dotfiles**: Put the files under `dotfiles/` in the templates back into your home directory.
- **Clean up**: Run package-manager cleanup when requested.

Every major stage can be skipped with a setup flag, so Gaudi can be used interactively, in a dry smoke setup, or as part of a more controlled machine provisioning flow.

### How prompts are answered

| How it is run | What happens at each prompt |
| --- | --- |
| In a terminal | You are asked: each Brewfile (all of it, or package by package), each list, each configuration script |
| With `--yes` | Everything is accepted |
| Without a terminal and without `--yes` | The safe default is taken: templates are cloned or updated, nothing optional is installed |

Generating an SSH key always needs a terminal, because it asks for an email and a passphrase; without one that step is skipped.

### When something fails

A package, hook or configuration script that fails does not stop the run. Gaudi carries on, prints every failure in a summary at the end and exits with status 1, so the same command can simply be run again after fixing them.

## CLI

After setup, Gaudi installs a `gaudi` command into `${GAUDI_BIN_DIR:-$HOME/.local/bin}` and adds that directory to the detected shell profile when needed.

| Command | What it does |
| --- | --- |
| `gaudi setup [flags]` | Run the setup again |
| `gaudi backup [output-dir]` | Capture the installed software (default: `./backup`) |
| `gaudi check [templates-dir] [--online]` | Check a templates directory for things that will not work; changes nothing |
| `gaudi doctor` | Show the install location, OS, shell, templates and whether Git and Homebrew are available; changes nothing |
| `gaudi version` | Print the installed version |
| `gaudi help` | Print the usage |

Setup flags:

```sh
gaudi setup --yes
gaudi setup --skip-prereqs
gaudi setup --skip-templates
gaudi setup --skip-software
gaudi setup --skip-configs
gaudi setup --skip-shell-helpers
gaudi setup --skip-ssh
gaudi setup --skip-dotfiles
gaudi setup --skip-cleanup
```

To see what a run would do without doing it:

```sh
GAUDI_DRY_RUN=true gaudi setup --yes --skip-prereqs
```

## Backup and Restore

Capture the software installed on the current machine:

```sh
gaudi backup
gaudi backup ./backup
```

A backup holds:

| File | What it captures |
| --- | --- |
| `Brewfile` | Taps, formulae, casks, Mac App Store apps, VS Code extensions and the language packages Homebrew tracks, each with its description (`brew bundle dump`) |
| `default.apt.list.sh` | Debian/Ubuntu: the packages you installed yourself (`apt-mark showmanual`) |
| `default.dnf.list.sh` | Fedora: the packages you installed yourself |
| `default.gem.list.sh` | Ruby gems in your user gem directory |
| `dotfiles/` | The files and directories named in the templates' `dotfiles.list` |

Limit what is backed up with `GAUDI_BACKUP_MANAGERS`:

```sh
GAUDI_BACKUP_MANAGERS="bundle dotfiles" gaudi backup ./backup
```

To restore on another machine:

1. Put the backup files in your templates repository and push it. The lists can go anywhere (for example under `lists/`); `dotfiles/` stays at the top.
2. On the new machine, run the installer and give it that repository when it asks for the templates URL, or set it up front:

```sh
GAUDI_DEFAULT_TEMPLATES_URL="git@github.com:you/your-templates.git" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)" gaudi --yes
```

A restore only adds software; it never removes what is already on the machine. If a package no longer exists, the rest is still restored and the failure is listed at the end.

What a backup does not contain: anything you did not list in `dotfiles.list`, and macOS preferences set with `defaults`, which belong in [configuration scripts](#configuration-scripts). Application settings are usually files, so they can be listed in `dotfiles.list` (for example `Library/Preferences/com.googlecode.iterm2.plist`).

## Environment Variables

Every setup flag has a variable, and a few more settings only exist as variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GAUDI` | `~/.gaudi` | Where Gaudi is installed |
| `GAUDI_REPO_URL` | `https://github.com/g-udi/gaudi.git` | Repository the installer clones |
| `GAUDI_BRANCH` | `master` | Branch the installer clones and updates |
| `GAUDI_TEMPLATES_LOCATION` | `$GAUDI/templates` | Where the templates live |
| `GAUDI_DEFAULT_TEMPLATES_URL` | `https://github.com/g-udi/gaudi-templates.git` | Templates repository offered at the prompt |
| `GAUDI_ASSUME_YES` | `false` | Same as `--yes` |
| `GAUDI_SKIP_PREREQS`, `GAUDI_SKIP_SSH`, `GAUDI_SKIP_TEMPLATES`, `GAUDI_SKIP_SHELL_HELPERS`, `GAUDI_SKIP_SOFTWARE`, `GAUDI_SKIP_CONFIGS`, `GAUDI_SKIP_DOTFILES`, `GAUDI_SKIP_CLEANUP` | `false` | Same as the matching `--skip-*` flag |
| `GAUDI_DRY_RUN` | `false` | Print install commands, hooks, configs and dotfiles instead of running them |
| `GAUDI_BUNDLE_NO_UPGRADE` | `false` | Install missing Brewfile entries without upgrading existing ones |
| `GAUDI_TARGET_SHELL` | from `$SHELL` | Shell whose profile gets the `PATH` and Homebrew lines |
| `GAUDI_SETUP_PROFILE` | per shell | Profile file to write to instead |
| `GAUDI_BIN_DIR` | `~/.local/bin` | Where the `gaudi` command is linked |
| `GAUDI_SSH_EMAIL` | asked | Email for a newly generated SSH key |
| `GAUDI_BACKUP_MANAGERS` | `bundle gem dotfiles` (plus `apt` on Debian, `dnf` on Fedora) | What `gaudi backup` captures |
| `GAUDI_HELPER_REPO_URL` | `https://github.com/g-udi/gaudi-shell.git` | Repository the gaudi-shell helper is cloned from |
| `GAUDI_BREW_BIN_DIRS` | the standard Homebrew locations | Colon-separated directories searched for a Homebrew that is not on `PATH` yet |

## Supported Systems and Shells

Fully automated OS paths:

- macOS
- Debian and Ubuntu
- Fedora

On Linux, Gaudi works for a regular user with `sudo` and for root. Homebrew refuses to run as root, so Brewfiles are skipped there; apt or dnf lists, configs and dotfiles still apply.

Shell profile support:

- Bash: `.bash_profile` on macOS, `.bashrc` elsewhere
- Zsh: `.zshrc`
- Fish: `.config/fish/config.fish`
- POSIX-like fallback: `.profile`

Set `GAUDI_TARGET_SHELL` to force profile installation for a shell other than `$SHELL`, and `GAUDI_SETUP_PROFILE` to write to a specific profile file.

## Templates

Gaudi templates live at:

```sh
${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}
```

If the templates directory is a Git checkout, setup can update it with `git pull --ff-only`; when that fails (local changes, no network) the existing templates are used. If it is a non-Git directory, Gaudi keeps it and uses it without deleting user files.

Default template repository:

```sh
https://github.com/g-udi/gaudi-templates.git
```

A templates repository holds Brewfiles, lists, hooks, configuration scripts and dotfiles. Gaudi finds them by file name, wherever they are in the repository. Templates are code that runs on your machine: only use a repository you trust.

### Software: Brewfiles

Software is declared in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile) and installed with `brew bundle`, which is idempotent and keeps going when a single package fails. Gaudi finds every file named `Brewfile` or `<name>.Brewfile` in the templates, asks whether to install it, and runs it.

One Brewfile can hold Homebrew taps, formulae and casks, Mac App Store apps, VS Code extensions, and npm, Go, Cargo and [uv](https://docs.astral.sh/uv/) packages:

```ruby
# @Name: Core tools
# @Description: Command-line tools and libraries

tap "koekeishiya/formulae"
# Lightweight and flexible command-line JSON processor
brew "jq"
cask "raycast"
mas "Amphetamine", id: 937984704
npm "eslint"
uv "pylint"
```

The two `@Name` / `@Description` comment lines are optional and only label the prompt. Split software into several Brewfiles (for example `core.Brewfile`, `apps.Brewfile`, `npm.Brewfile`) to accept or skip each group on its own.

Set `GAUDI_BUNDLE_NO_UPGRADE=true` to install missing packages without upgrading the ones already there, and `GAUDI_DRY_RUN=true` to print the install commands, hooks and configuration scripts that would run without running any of them.

### Software: lists for other package managers

Package managers Homebrew does not drive keep the list format, a shell file with metadata and an array:

```sh
# @Name: Default
# @Description: Debian packages
# @List: aptList
aptList=(
  "build-essential"
  "pkg-config::Manage compile and link flags for libraries"
)
```

Supported list targets:

- `apt`: Debian/Ubuntu packages, in files such as `default.apt.list.sh`
- `dnf`: Fedora packages, in files such as `default.dnf.list.sh`
- `gem`: Ruby gems, in files such as `default.gem.list.sh`

Older `brew`, `cask`, `tap`, `mas`, `npm`, `pip` and `go` lists are no longer installed; setup prints a warning for each one it finds so it can be moved into a Brewfile. Python tools go in a Brewfile as `uv "<tool>"` entries, because `pip install --user` is refused by current Homebrew and Debian Pythons.

### Hooks

Hooks are shell scripts in the templates that Gaudi sources around the software steps. The file name decides when they run:

| File name | Runs |
| --- | --- |
| `pre.bundle.hooks.sh` / `post.bundle.hooks.sh` | Before the first / after the last Brewfile |
| `pre.bundle-<name>.hooks.sh` / `post.bundle-<name>.hooks.sh` | Around `<name>.Brewfile`, only if it was accepted |
| `pre.bundle-<name>.<topic>.hooks.sh` / `post.bundle-<name>.<topic>.hooks.sh` | Same, when one Brewfile needs several hooks |
| `pre.apt.hooks.sh`, `pre.dnf.hooks.sh`, `post.gem.hooks.sh`, ... | Around the apt, dnf and gem lists |

Hooks run inside the setup, so they can use its helpers: `command_exists <tool>`, `gaudi::confirm "Question?" "n"` (which follows `--yes` and the no-terminal defaults), and `gaudi::record_failure "what failed"` to report a problem in the final summary.

### Configuration Scripts

Configuration scripts are discovered from templates using:

```sh
*.configs.<os>.sh
*.configs.sh
```

where `<os>` is `osx`, `debian` or `fedora`; files without it apply to all. Each configuration script should define `_info` and `_command`:

```sh
_info="Show Finder path bar"
_command() {
  defaults write com.apple.finder ShowPathbar -bool true
}
```

Setup first asks whether to apply all of them, and otherwise asks for each one, showing its `_info`.

### Dotfiles

`dotfiles.list` names what `gaudi backup` should copy, one path per line, relative to your home directory:

```text
# shell and Git
.zshrc
.gitconfig
.config/kitty          # a whole directory
```

Everything under `dotfiles/` at the top of the templates is restored by `gaudi setup`, keeping the same layout (`dotfiles/.config/kitty/kitty.conf` goes to `~/.config/kitty/kitty.conf`). Setup lists what would change and asks once. A file that is already identical is left alone; a different one is first moved aside as `<file>.gaudi-backup`.

Do not list secrets such as SSH keys or tokens when the templates repository is public.

### Checking templates

```sh
gaudi check                # the configured templates
gaudi check ./my-templates
gaudi check --online       # also ask Homebrew whether every formula and cask still exists
```

`gaudi check` reads a templates directory and reports what would not work, without changing anything:

- a Brewfile that Homebrew cannot read, or a `mas` entry without its id
- a hook or configuration script whose file name means it never runs (a typo, a Brewfile that does not exist, an unknown OS)
- a list without its `@List` line or its array, and old lists that are no longer installed
- a configuration script without `_command`
- `dotfiles.list` entries that point outside the home directory

It exits 1 when it finds errors, so it can guard a templates repository in CI; the [default templates](https://github.com/g-udi/gaudi-templates) do exactly that. With `--online` it also reports formulae and casks that Homebrew has removed, disabled or deprecated (one lookup per package, so it is slow).

## Behind the Scenes

```text
bin/
  gaudi          CLI entrypoint
  colors.sh      terminal color detection
  commands.sh    command resolution wrappers
  helpers.sh     OS/shell/profile/template helpers
  installer.sh   Brewfile and software-list installation logic
configs/
  configure-gaudi.sh
  configure-ssh.sh
lib/
  debian/        fedora/ and osx/ hold the same three files
    cleanup.sh
    configure.sh
    install-pre-requisits.sh
  osx/
    cleanup.sh
    configure.sh
    install-pre-requisits.sh
  install-configurations.sh
  install-dotfiles.sh
  install-shell-helpers.sh
  install-software.sh
test/
  run            test runner
  unit/          unit tests (bats)
  e2e/           end-to-end tests on simulated machines (bats)
  real/          real end-to-end runs (Docker, CI)
  fakes/         fake brew, apt, sudo, curl, ... for the simulated machines
  support/       drivers that load the code the way setup.sh does, and a pseudo-terminal
  helper.bash    the sandbox every test runs in
.github/workflows/tests.yml
install.sh
setup.sh
backup.sh
check.sh
```

## Testing

```sh
test/run                # lint + unit + end-to-end (a few minutes)
test/run unit           # one suite: lint, unit, e2e or real
test/run --every-bash   # also under /bin/bash, the 3.2 that ships with macOS
test/run real           # real end-to-end runs in Docker containers
test/run e2e --filter "backup"
```

The suite is written with [bats-core](https://github.com/bats-core/bats-core). The runner uses `bats` from `PATH` (`brew install bats-core`, `apt-get install bats`), or the copy in a sibling [gaudi-shell](https://github.com/g-udi/gaudi-shell) checkout.

| Suite | What it covers |
| --- | --- |
| `lint` | Bash syntax (also under bash 3.2), [ShellCheck](https://www.shellcheck.net/), and checks that every script, library function, setup flag and `GAUDI_*` variable is both tested and documented |
| `unit` | Every function and every setup step on its own: prompts, OS and shell detection, Brewfile and list installation, hooks, configs, dotfiles, SSH, templates, prerequisites, the CLI, the installer, backup, the templates checker. Colours and prompts are also tested on a real pseudo-terminal, typing the answers key by key |
| `e2e` | The real `install.sh`, `setup.sh` and `gaudi backup` on simulated machines: a fresh Mac, Debian and Fedora from the one-line installer, backup on one machine and restore on another, failures and reruns |
| `real` | Nothing simulated: Debian and Fedora containers, running as root, where the real `apt` and `dnf` install packages, and packages and dotfiles are backed up, removed and restored. `test/real/macos.sh` does the same with the real Homebrew and only runs in CI or with `GAUDI_E2E_REAL_MACOS=1` |

Unit and end-to-end tests never touch the machine they run on. Each test gets a throwaway home directory and a `PATH` that holds only fake tools (`test/fakes`: brew, apt, sudo, curl, ssh-keygen, ...) and a whitelist of coreutils. The fake package managers record what they "install", which is how a restored machine is compared with the one that was backed up.

### Continuous integration

[GitHub Actions](https://github.com/g-udi/gaudi/actions/workflows/tests.yml) runs on every pull request, on every push to `master`, and in the merge queue:

| Job | Runs |
| --- | --- |
| `suite` | `test/run --every-bash` on macOS and Ubuntu |
| `real-linux` | `test/run real`: real apt in a Debian container and real dnf in a Fedora container |
| `real-macos` | `test/real/macos.sh`: a real formula installed, backed up, removed and restored with Homebrew |
| `tests passed` | Succeeds only when all of the above did |

To block merging until the tests pass, require the `tests passed` check on `master` (repository Settings, Branches or Rulesets). It is one check, so the rule does not need changing when jobs are added.

### Rules the code follows

These are enforced by the suite; they are listed here because each one was a real bug.

- **Bash 3.2 compatible.** A fresh Mac only has Bash 3.2: no associative arrays, no `mapfile`, and empty arrays are an error under `set -u`.
- **Sourcing template files goes through `gaudi::source_guarded`.** On Bash 3.2, `source file || handle` still ends the run when a command in the file fails.
- **Loops that prompt read their list on their own file descriptor** (`while read -u 3 ...; done 3< <(...)`), otherwise the prompt reads the list instead of the keyboard.
- **Installer scripts are downloaded with `gaudi::run_remote_script`**, never `bash -c "$(curl ...)"`, which runs an empty script successfully when the download fails.
- **Nothing reads `GAUDI_SHELL` or `GAUDI_SHELL_PROFILE`.** Those belong to [gaudi-shell](https://github.com/g-udi/gaudi-shell) and are exported wherever it is loaded.
- **A failure is recorded with `gaudi::record_failure`, not allowed to abort.**

## Credits & Inspirations

- [Homebrew](https://brew.sh/)
- [mas](https://github.com/mas-cli/mas)
- [oh-my-zsh](https://ohmyz.sh/)
- [gaudi-templates](https://github.com/g-udi/gaudi-templates)
- [gaudi-shell](https://github.com/g-udi/gaudi-shell)

## License

[MIT](LICENSE)
