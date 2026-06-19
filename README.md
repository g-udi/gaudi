# Gaudi

### _Gaudi: Craft Your Perfect Dev Environment_

 🏗️ Automate your machine setup
 🎨 Customize with templates
 🚀 From fresh install to fully equipped in minutes

As a developer or tech enthusiast, you have probably experienced the friction of setting up a new machine. Whether it is a fresh operating system install or a brand-new device, the process of reinstalling your go-to applications, configuring development environments, and getting everything to run smoothly can feel like a tedious chore. That is why I created [**Gaudi**](https://github.com/g-udi/gaudi): a tool designed to make setting up a new machine efficient, consistent, and repeatable.

![2024-09-20 12 07 54](https://github.com/user-attachments/assets/96a8dafb-d5e6-4e09-9476-b90a044976a6)

## The Problem: Time-Consuming Setup

Anyone who has had to reconfigure a new system from scratch understands the pain. You are faced with hours of:

- Installing software and tools such as [Homebrew](https://brew.sh/), [npm](https://www.npmjs.com/), [mas](https://github.com/mas-cli/mas), `apt`, and others.
- Customizing system preferences.
- Setting up your favorite applications.
- Re-configuring settings to match your old system.

It is a repetitive, manual process, and there is always a chance you will forget one or two critical steps, leaving your environment not quite right. Multiply that by each new device, and you are looking at a major time sink.

Gaudi is a Bash-based command line tool for installing and setting up machines from reusable software lists, hooks, configuration scripts, and templates.

The main motivation behind Gaudi is:

- Have a clean, reproducible way to set up a machine from scratch by installing all the software and packages needed.
- Share machine setups between users with [templates](https://github.com/g-udi/gaudi-templates).
- Keep the bootstrapper predictable while still installing cleanly for Bash, Zsh, Fish, and POSIX-style login shells.

> Note: Gaudi automates macOS and Debian/Ubuntu paths. Other Linux families are detected and reported rather than guessed.

## Installation

Install Gaudi from the command line:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi/master/install.sh)"
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

## What does Gaudi do?

Gaudi automates the setup path in separate, skippable stages:

- **Install the prerequisites for the OS**: OS detection is automatic. macOS and Debian/Ubuntu have fully automated paths.
- **Configure SSH**: Ensure SSH keys and Git access are ready before cloning template repositories.
- **Configure Gaudi templates**: Clone or update the templates repository.
- **Install shell helpers**: Suggest shell helpers such as [gaudi-bash](https://github.com/g-udi/gaudi-bash) or [oh-my-zsh](https://ohmyz.sh/).
- **Install software lists**: Install packages from template list files.
- **Run configuration scripts**: Apply OS-specific or shared machine configuration scripts from templates.
- **Clean up**: Run package-manager cleanup when requested.

Every major stage can be skipped with a setup flag, so Gaudi can be used interactively, in a dry smoke setup, or as part of a more controlled machine provisioning flow.

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

## Supported Systems and Shells

Fully automated OS paths:

- macOS
- Debian and Ubuntu

Shell profile support:

- Bash: `.bash_profile` on macOS, `.bashrc` elsewhere
- Zsh: `.zshrc`
- Fish: `.config/fish/config.fish`
- POSIX-like fallback: `.profile`

Set `GAUDI_TARGET_SHELL` to force profile installation for a shell other than `$SHELL`.

## Behind the Scenes

### Folder and File Structure

```text
bin/
  gaudi          CLI entrypoint
  colors.sh      terminal color detection
  commands.sh    command resolution wrappers
  helpers.sh     OS/shell/profile/template helpers
  installer.sh   software-list installation logic
  loaders.sh     compatibility loaders
configs/
  configure-gaudi.sh
  configure-ssh.sh
lib/
  debian/
    cleanup.sh
    configure.sh
    install-pre-requisits.sh
  osx/
    cleanup.sh
    configure.sh
    install-pre-requisits.sh
  install-configurations.sh
  install-shell-helpers.sh
  install-software.sh
test/
  smoke.sh
install.sh
setup.sh
backup.sh
```

### Templates

Gaudi templates live at:

```sh
${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}
```

If the templates directory is a Git checkout, setup can update it with `git pull --ff-only`. If it is a non-Git directory, Gaudi keeps it and uses it without deleting user files.

Default template repository:

```sh
https://github.com/g-udi/gaudi-templates.git
```

Templates are shell scripts that can describe package lists, hooks, and machine configuration commands.

### Software Lists

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

Hooks run before or after software lists:

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

Combining hooks with template-based installation gives you control over the exact setup process without editing Gaudi itself.

### Configuration Scripts

Configuration scripts are discovered from templates using:

```sh
*.configs.<os>.sh
*.configs.sh
```

Each configuration script should define `_info` and `_command`:

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

Backup writes list files for available package managers and skips missing tools cleanly. You can limit backup managers with `GAUDI_BACKUP_MANAGERS`, for example:

```sh
GAUDI_BACKUP_MANAGERS="brew cask npm" gaudi backup ./backup
```

## Validation

Run the smoke suite before committing changes:

```sh
./test/smoke.sh
```

It checks Bash syntax, ShellCheck when available, CLI dispatch, cross-shell profile installation for Fish, template software-list installation in dry-run mode, and backup generation.

## Credits & Inspirations

- [Homebrew](https://brew.sh/)
- [mas](https://github.com/mas-cli/mas)
- [oh-my-zsh](https://ohmyz.sh/)
- [gaudi-templates](https://github.com/g-udi/gaudi-templates)
- [gaudi-bash](https://github.com/g-udi/gaudi-bash)
