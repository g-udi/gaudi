# Changelog

All notable changes to Gaudi are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Changed

- A hook, configuration script or list file is reported as failed when any command in it fails without the script handling it (the rule `set -e` uses), not only when its last command fails. The rest of the script still runs. The summary names the line.
- `exit` in a hook or configuration script stops that script instead of the whole setup, and is reported as a failure: use `return` to stop early.

### Fixed

- `gaudi backup` no longer stops halfway, without a summary, when `apt-mark`, `dnf`, `pacman` or `zypper` cannot list the installed packages. The failure is reported, no list is written for that manager, and the other managers and the dotfiles are still backed up.
- A `dotfiles.list` entry of `.` or `./` copied the whole home directory into the backup. Backup, restore and `gaudi check` now share one rule: a path must be inside the home directory, and may not be the home directory itself or leave it through a symlinked directory.
- A hook that ended the run outright (an unset variable, its own `set -e`) left no summary; the failures are now printed before setup exits.

## 2.0.0 - 2026-11-10

Software moves to Brewfiles. Templates written for 1.x need converting: `gaudi check` lists what has to change.

### Changed

- Software is declared in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile) (`Brewfile`, `<name>.Brewfile`) and installed with `brew bundle`. The `brew`, `cask`, `tap`, `mas`, `npm`, `pip` and `go` lists are no longer installed; setup reports each one it finds.
- Hooks are named `pre|post.bundle[-<name>[.<topic>]].hooks.sh`.
- `gaudi backup` writes one `Brewfile` instead of a list per package manager.
- A failed package, hook or config no longer stops the run; failures are listed at the end and setup exits 1.
- The shell helper offered is [gaudi-shell](https://github.com/g-udi/gaudi-shell), which replaced gaudi-bash. Its command is `gshell`, so `gaudi` always means this tool.
- `GAUDI_SETUP_SHELL` and `GAUDI_SETUP_PROFILE` replace the internal names that clashed with gaudi-shell's exported variables.

### Added

- Fedora, Arch and openSUSE support (dnf, pacman and zypper lists, prerequisites, cleanup, backup).
- Dotfiles: `dotfiles.list` for backup, a `dotfiles/` directory restored by setup, `--skip-dotfiles`.
- Ruby gems in the backup.
- Package-by-package picking inside a Brewfile.
- `gaudi check` to validate a templates directory, with `--online` to find packages Homebrew no longer has.
- `gaudi doctor`, `gaudi version`, and a `gaudi` command linked into `~/.local/bin`.
- Running as root, with or without `sudo` (containers, fresh servers).
- `GAUDI_DRY_RUN`, `GAUDI_BUNDLE_NO_UPGRADE`, `GAUDI_BRANCH`, `GAUDI_SSH_EMAIL` and the other variables listed in the README.
- A test suite (`test/run`): lint, unit and end-to-end tests on simulated machines, real runs in Debian, Fedora, openSUSE and Arch containers and on macOS, all run by GitHub Actions before a merge.

### Fixed

- Prompts inside a list of Brewfiles, lists or configs answered "no" on their own.
- Declining a configuration script ended the setup.
- The `gaudi` command did not work through its symlink.
- Setup hung without a terminal (SSH email prompt, templates URL prompt).
- A fresh Mac: the installer trusted the Git stub before the Command Line Tools existed, and Homebrew was not added to the shell profile.
- Failures on the Bash 3.2 that ships with macOS.
- A failed download of an installer script was treated as success.
- Rerunning the installer could not update an existing install.

## 1.x

The original list-based bootstrapper.
