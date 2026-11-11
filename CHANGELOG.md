# Changelog

All notable changes to Gaudi are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Changed

- A hook, configuration script or list file is reported as failed when any command in it fails without the script handling it (the rule `set -e` uses), not only when its last command fails. The rest of the script still runs. The summary names the line.
- `exit` in a hook or configuration script stops that script instead of the whole setup, and is reported as a failure: use `return` to stop early.
- A list file runs in a subshell and only the items of its array are used. Variables a list file set no longer reach the steps after it (hooks are the place for that), and an item has to fit on one line.
- A dry run (`GAUDI_DRY_RUN=true`) no longer sources configuration scripts or list files, so nothing they do outside `_command` or the array runs. `_info` and `_command` are read from the text of a config, the array from the text of a list; a list that builds its array with code is named and left unread.
- `--yes` now also covers the two prompts it used to stop at on a terminal: the templates URL (the default repository is taken) and Homebrew's "press RETURN" on Linux and in `install.sh` (the installer runs with `NONINTERACTIVE=1`, as it already did on macOS).
- A symlinked dotfile is backed up as the file or directory it points to instead of as a link that only works on the machine it came from. A link to a directory outside the home directory is skipped with a warning. Restore also copies symlinks under `dotfiles/` that point to a file.
- `gaudi check` reads lists the way setup does. A list whose code fails on the checking machine is a warning that gives the reason.
- Only six colour variables are set for hooks and configs: `NC`, `RED`, `GREEN`, `YELLOW`, `BLUE` and `MAGENTA`. The bold, underline, background and intense variants (58 variables Gaudi never used, one of them with a wrong code) are gone; write `${CYAN:-}` style defaults or the escape sequence itself if a template used one.
- Helper functions are named `gaudi::*` throughout: `gaudi::detect_os`, `gaudi::detect_shell`, `gaudi::read_answer`, `gaudi::read_email`, `gaudi::read_git_url`, `gaudi::install_list_items`, `gaudi::gem_install`. The old names (`get_os`, `get_shell_type`, `read_answer`, `read_email`, `read_git_url`, `installSoftwareList`, `gem_install_or_update`, `command_exists`) keep working.
- `GAUDI_GSHELL_REPO_URL` is the new name of `GAUDI_HELPER_REPO_URL`, which named the gaudi-shell repository and was easy to take for a gaudi-helper setting. The old name still works.
- The per-OS prerequisite scripts are spelt `lib/<os>/install-prerequisites.sh`, and the five identical `lib/<os>/configure.sh` files are gone: setup sources `lib/install-configurations.sh` directly.
- In CI the real Linux run fails when Docker is not available instead of passing with a SKIP, and the workflow's actions are pinned to a commit.

### Added

- `gaudi backup --help`; any other option is refused with status 64 instead of being taken for the output directory.
- Brewfile entries in single quotes and inside Ruby blocks (`if OS.mac?` ... `end`) are recognised everywhere: package-by-package picking asks about them, `gaudi check` no longer warns about them and finds their duplicates. `flatpak`, `winget` and `krew` entries are known; `whalebrew`, which Homebrew dropped, is not.
- A real end-to-end pass as a regular user who reaches the package manager through `sudo`, next to the root pass.

### Removed

- The `mas` and `npm` wrapper functions. They made `type npm` succeed in a hook even when npm was not installed. `brew` and `sudo` keep their wrappers.
- `_echo`, `gaudi::brew_bin` and `gaudi::resolved_command_path`, which nothing called.

### Fixed

- `gaudi backup` no longer stops halfway, without a summary, when `apt-mark`, `dnf`, `pacman` or `zypper` cannot list the installed packages. The failure is reported, no list is written for that manager, and the other managers and the dotfiles are still backed up.
- A `dotfiles.list` entry of `.` or `./` copied the whole home directory into the backup. Backup, restore and `gaudi check` now share one rule: a path must be inside the home directory, and may not be the home directory itself or leave it through a symlinked directory.
- A hook that ended the run outright (an unset variable, its own `set -e`) left no summary; the failures are now printed before setup exits.
- The "Shell helpers" banner showed its colour codes as text (`\033[0;33m`) on a colour terminal.
- A list that made its array with `declare -a` was skipped by setup as "array not defined" although `gaudi check` accepted it.
- `gaudi check` reported a configuration script whose `_command()` has its opening brace on the next line as having no `_command`.
- With Brewfiles named `dev` and `dev.tools`, the hook `pre.bundle-dev.tools.hooks.sh` also ran as a topic hook of `dev`. A hook now belongs to the longest Brewfile name it matches.
- Setup, `gaudi check`, `gaudi backup` and `gaudi doctor` each had their own idea of which files are Brewfiles and lists, what a package line looks like and how `dotfiles.list` is read, and had drifted apart. They now share one definition (`bin/templates.sh`).

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
