# Gaudi

Gaudi is a workstation bootstrapper for repeatable development-machine setup. It installs prerequisites, clones a templates repository, installs software lists, applies machine configuration scripts, and exposes a `gaudi` CLI for setup, backup, diagnostics, and version checks.

The implementation is Bash-based for portability and predictable execution, but it detects and supports Bash, Zsh, Fish, and POSIX-style login shells when installing the CLI and updating profile files.

## Install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)"
```

Manual install:

```sh
git clone https://github.com/g-udi/gaudi.git ~/.gaudi
~/.gaudi/setup.sh
```

Safe smoke setup that does not install packages or clone templates:

```sh
~/.gaudi/setup.sh --yes --skip-prereqs --skip-templates --skip-software --skip-configs --skip-shell-helpers --skip-ssh --skip-cleanup
```

## CLI

After setup, Gaudi installs a `gaudi` command into `${GAUDI_BIN_DIR:-$HOME/.local/bin}` and adds that directory to the detected shell profile when needed.

```sh
gaudi setup
gaudi backup
gaudi doctor
gaudi version
gaudi help
```

Setup flags:

```sh
gaudi setup --yes
gaudi setup --skip-prereqs
gaudi setup --skip-templates
gaudi setup --skip-software
gaudi setup --skip-configs
gaudi setup --skip-shell-helpers
gaudi setup --skip-ssh
gaudi setup --skip-cleanup
```

## Supported Systems

Fully automated paths:

- macOS
- Debian and Ubuntu

Shell profile support:

- Bash: `.bash_profile` on macOS, `.bashrc` elsewhere
- Zsh: `.zshrc`
- Fish: `.config/fish/config.fish`
- POSIX-like fallback: `.profile`

Unsupported Linux families are detected and reported rather than guessed.

Set `GAUDI_TARGET_SHELL` to force profile installation for a shell other than `$SHELL`.

## Templates

Gaudi templates live at:

```sh
${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}
```

If the templates directory is a Git checkout, setup can update it with `git pull --ff-only`. If it is a non-Git directory, Gaudi keeps it and uses it without deleting user files.

Default template repository:

```sh
https://github.com/g-udi/gaudi-templates.git
```

## Software Lists

Software list files are shell files with metadata and an array:

```sh
# @Name: Default
# @Description: Core Homebrew formulae
# @List: brewList
export brewList=(
  "git::Distributed version control"
  "jq::Command-line JSON processor"
)
```

Supported list targets:

- `apt`: Debian/Ubuntu packages, matching files such as `default.apt-get.sh`
- `tap`: Homebrew taps
- `brew`: Homebrew formulae
- `cask`: Homebrew casks on macOS
- `mas`: Mac App Store apps on macOS
- `npm`: global npm packages
- `pip`: user Python packages through `python3 -m pip`
- `go`: Go packages through `go install`
- `gem`: Ruby gems

Hooks use:

```sh
pre.<target>.hooks.sh
post.<target>.hooks.sh
```

Examples:

```sh
pre.brew.hooks.sh
post.npm.hooks.sh
pre.apt.hooks.sh
```

## Configuration Scripts

Configuration scripts are discovered from templates using:

```sh
*.configs.<os>.sh
*.configs.sh
```

Each config script should define `_info` and `_command`:

```sh
_info="Show Finder path bar"
_command() {
  defaults write com.apple.finder ShowPathbar -bool true
}
```

## Backup

Generate software list files from the current machine:

```sh
gaudi backup
gaudi backup ./backup
```

Backup writes list files for available package managers and skips missing tools cleanly.

## Repository Layout

```text
bin/
  gaudi          CLI entrypoint
  colors.sh      terminal color detection
  commands.sh    command resolution wrappers
  helpers.sh     OS/shell/profile/template helpers
  installer.sh   software-list installation logic
configs/
  configure-gaudi.sh
  configure-ssh.sh
lib/
  debian/
  osx/
  install-configurations.sh
  install-shell-helpers.sh
  install-software.sh
test/
  smoke.sh
install.sh
setup.sh
backup.sh
```

## Validation

Run the smoke suite:

```sh
./test/smoke.sh
```

It checks Bash syntax, ShellCheck when available, CLI dispatch, cross-shell profile installation for Fish, and a no-side-effect setup path.
