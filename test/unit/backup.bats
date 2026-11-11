#!/usr/bin/env bats
# backup.sh (reached through `gaudi backup`)

load ../helper

setup() {
    gaudi_sandbox darwin
    CLI="$GAUDI_ROOT/bin/gaudi"
}

# Pretend things are installed on the machine
installed() {
    mkdir -p "$MACHINE/brew"
    printf '%s\n' "$2" >> "$MACHINE/$1"
}

@test "backup writes a Brewfile describing the machine" {
    installed brew/tap.txt "example/tap"
    installed brew/brew.txt "jq"
    installed brew/cask.txt "kitty"
    installed brew/mas.txt "Amphetamine|937984704"
    installed brew/npm.txt "eslint"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "brew bundle dump --force --file=$SANDBOX/out/Brewfile"
    refute_called "--describe"
    assert_output_contains "[OK] Wrote $SANDBOX/out/Brewfile"
    assert_output_contains "[OK] Backup complete"
    assert_equal "$(cat "$SANDBOX/out/Brewfile")" 'tap "example/tap"
# Description of jq
brew "jq"
# Description of kitty
cask "kitty"
mas "Amphetamine", id: 937984704
npm "eslint"'
}

@test "backup defaults to ./backup" {
    installed brew/brew.txt "jq"
    run "$CLI" backup
    assert_success
    assert_file_contains "$WORK/backup/Brewfile" 'brew "jq"'
    assert_equal "$(ls -A "$WORK")" "backup"
}

@test "backup creates the output directory, including parents" {
    run "$CLI" backup "$SANDBOX/a/b/c"
    assert_success
    assert_file_exists "$SANDBOX/a/b/c/Brewfile"
}

@test "backup replaces a previous Brewfile" {
    mkdir -p "$SANDBOX/out"
    printf 'brew "stale"\n' > "$SANDBOX/out/Brewfile"
    installed brew/brew.txt "jq"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    refute_file_contains "$SANDBOX/out/Brewfile" "stale"
    assert_file_contains "$SANDBOX/out/Brewfile" 'brew "jq"'
}

@test "backup works with an output path that contains spaces" {
    installed brew/brew.txt "jq"
    run "$CLI" backup "$SANDBOX/my backup"
    assert_success
    assert_file_contains "$SANDBOX/my backup/Brewfile" 'brew "jq"'
}

@test "backup without Homebrew warns and writes no Brewfile" {
    remove_tool brew
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Skipping Brewfile backup: Homebrew is not installed"
    refute_file_exists "$SANDBOX/out/Brewfile"
}

@test "a failing dump makes the backup fail" {
    export FAKE_BREW_DUMP_FAIL=1
    run "$CLI" backup "$SANDBOX/out"
    assert_failure 1
    assert_output_contains "brew bundle dump"
    refute_output_contains "Backup complete"
}

@test "macOS does not write an apt list" {
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    refute_file_exists "$SANDBOX/out/default.apt.list.sh"
    refute_called "apt-mark"
}

@test "Debian also backs up the packages installed by hand, sorted, as a Gaudi list" {
    gaudi_sandbox debian
    printf 'zsh\ncurl\nhtop\n' > "$MACHINE/apt.txt"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "apt-mark showmanual"
    assert_equal "$(cat "$SANDBOX/out/default.apt.list.sh")" '# @Name: Default
# @List: aptList
aptList=(
  "curl"
  "htop"
  "zsh"
)'
}

@test "the apt list a backup writes is a list Gaudi can install" {
    gaudi_sandbox debian
    printf 'curl\nhtop\n' > "$MACHINE/apt.txt"
    "$CLI" backup "$SANDBOX/templates/lists" >/dev/null 2>&1
    rm "$MACHINE/apt.txt"
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_file_contains "$MACHINE/apt.txt" "curl"
    assert_file_contains "$MACHINE/apt.txt" "htop"
}

@test "Debian with Homebrew writes both files" {
    gaudi_sandbox debian
    add_tool brew
    installed brew/brew.txt "jq"
    printf 'curl\n' > "$MACHINE/apt.txt"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_file_contains "$SANDBOX/out/Brewfile" 'brew "jq"'
    assert_file_contains "$SANDBOX/out/default.apt.list.sh" '"curl"'
}

@test "GAUDI_BACKUP_MANAGERS limits what is backed up" {
    gaudi_sandbox debian
    add_tool brew
    export GAUDI_BACKUP_MANAGERS="apt"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_file_exists "$SANDBOX/out/default.apt.list.sh"
    refute_file_exists "$SANDBOX/out/Brewfile"
    refute_called "brew bundle"
}

@test "asking for apt on a machine without it is a warning" {
    export GAUDI_BACKUP_MANAGERS="bundle apt"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Skipping apt backup: apt-mark is not available"
    assert_file_exists "$SANDBOX/out/Brewfile"
}

@test "old manager names point at the Brewfile" {
    for name in brew cask tap mas npm pip go; do
        export GAUDI_BACKUP_MANAGERS="$name"
        run "$CLI" backup "$SANDBOX/out"
        assert_success
        assert_output_contains "'$name' is now part of the Brewfile: use GAUDI_BACKUP_MANAGERS=bundle"
    done
    refute_called "brew bundle"
}

@test "an unknown manager name is a warning" {
    export GAUDI_BACKUP_MANAGERS="bundle floppy"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Unknown backup manager: floppy"
    assert_file_exists "$SANDBOX/out/Brewfile"
}

@test "backup.sh can be run directly" {
    installed brew/brew.txt "jq"
    run "$GAUDI_ROOT/backup.sh" "$SANDBOX/out"
    assert_success
    assert_file_contains "$SANDBOX/out/Brewfile" 'brew "jq"'
}

@test "backup changes nothing on the machine besides the backup itself" {
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_cwd_clean
    refute_file_exists "$HOME/.zshrc"
    refute_called "install"
}

# --- gems, dnf ---------------------------------------------------------------------------

@test "backup writes the user-installed gems as a Gaudi list" {
    printf 'tmuxinator\nbundler\n' > "$MACHINE/gem.txt"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_equal "$(cat "$SANDBOX/out/default.gem.list.sh")" '# @Name: Default
# @List: gemList
gemList=(
  "bundler"
  "tmuxinator"
)'
}

@test "backup writes no gem list when there are no user-installed gems" {
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "No user-installed gems to back up"
    refute_file_exists "$SANDBOX/out/default.gem.list.sh"
}

@test "backup without ruby skips gems with a warning" {
    remove_tool ruby gem
    export GAUDI_BACKUP_MANAGERS="gem"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Skipping gem backup: ruby and gem are not available"
}

@test "the gem list a backup writes is a list Gaudi can install" {
    printf 'tmuxinator\n' > "$MACHINE/gem.txt"
    "$CLI" backup "$SANDBOX/templates/lists" >/dev/null 2>&1
    rm "$MACHINE/gem.txt"
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"
}

@test "Fedora backs up the packages installed by hand as a dnf list" {
    gaudi_sandbox fedora
    printf 'zsh\nhtop\n' > "$MACHINE/dnf.txt"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "dnf repoquery --userinstalled"
    assert_equal "$(cat "$SANDBOX/out/default.dnf.list.sh")" '# @Name: Default
# @List: dnfList
dnfList=(
  "htop"
  "zsh"
)'
    refute_file_exists "$SANDBOX/out/default.apt.list.sh"
}

@test "asking for dnf on a machine without it is a warning" {
    export GAUDI_BACKUP_MANAGERS="dnf"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Skipping dnf backup: dnf is not available"
}

@test "an older Homebrew, which only describes when asked, still gives a described Brewfile" {
    export FAKE_BREW_LEGACY=1
    installed brew/brew.txt "jq"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "brew bundle dump --describe --force --file=$SANDBOX/out/Brewfile.described"
    assert_equal "$(cat "$SANDBOX/out/Brewfile")" '# Description of jq
brew "jq"'
    refute_file_exists "$SANDBOX/out/Brewfile.described"
}

@test "an empty machine backs up to an empty Brewfile without leaving temporary files" {
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_equal "$(ls -A "$SANDBOX/out")" "Brewfile"
}

@test "Arch backs up the explicitly installed packages as a pacman list" {
    gaudi_sandbox arch
    printf 'zsh\nhtop\n' > "$MACHINE/pacman.txt"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "pacman -Qqe"
    assert_equal "$(cat "$SANDBOX/out/default.pacman.list.sh")" '# @Name: Default
# @List: pacmanList
pacmanList=(
  "htop"
  "zsh"
)'
}

@test "openSUSE backs up the user-installed packages as a zypper list" {
    gaudi_sandbox opensuse
    printf 'zsh\nhtop\n' > "$MACHINE/zypper.txt"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_called "zypper --quiet packages --userinstalled"
    assert_equal "$(cat "$SANDBOX/out/default.zypper.list.sh")" '# @Name: Default
# @List: zypperList
zypperList=(
  "htop"
  "zsh"
)'
}

@test "asking for pacman or zypper on a machine without them is a warning" {
    export GAUDI_BACKUP_MANAGERS="pacman zypper"
    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_output_contains "Skipping pacman backup: pacman is not available"
    assert_output_contains "Skipping zypper backup: zypper is not available"
}

# --- a package manager that cannot be queried ----------------------------------------

@test "Debian: a failing apt query is reported and the rest of the backup still happens" {
    gaudi_sandbox debian
    add_tool brew
    installed brew/brew.txt "jq"
    printf 'tmuxinator\n' > "$MACHINE/gem.txt"
    printf 'x\n' | write_file "$HOME/.zshrc"
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    printf '.zshrc\n' | write_file "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    export FAKE_QUERY_FAIL=1

    run "$CLI" backup "$SANDBOX/out"
    assert_failure 1
    assert_output_contains "1 step(s) failed"
    assert_output_contains "apt backup: apt-mark showmanual"
    refute_output_contains "Backup complete"
    # No list that would pass for a machine without packages
    refute_file_exists "$SANDBOX/out/default.apt.list.sh"
    # Everything after apt was still backed up
    assert_file_contains "$SANDBOX/out/Brewfile" 'brew "jq"'
    assert_file_contains "$SANDBOX/out/default.gem.list.sh" '"tmuxinator"'
    assert_file_exists "$SANDBOX/out/dotfiles/.zshrc"
}

@test "Fedora, Arch and openSUSE: a failing package query is reported the same way" {
    for os in fedora arch opensuse; do
        gaudi_sandbox "$os"
        printf 'tmuxinator\n' > "$MACHINE/gem.txt"
        export FAKE_QUERY_FAIL=1

        run "$CLI" backup "$SANDBOX/out-$os"
        assert_failure 1
        assert_output_contains "1 step(s) failed"
        assert_output_contains " backup: "
        assert_equal "$(ls -A "$SANDBOX/out-$os")" "default.gem.list.sh"
    done
    assert_output_contains "zypper backup: zypper packages --userinstalled"
}

@test "a manager that fails in any other way is recorded and the next one still runs" {
    # The output directory cannot be written to: the gem list fails, dotfiles are still tried
    printf 'tmuxinator\n' > "$MACHINE/gem.txt"
    export GAUDI_BACKUP_MANAGERS="gem dotfiles"
    mkdir -p "$SANDBOX/out"
    mkdir "$SANDBOX/out/default.gem.list.sh"

    run "$CLI" backup "$SANDBOX/out"
    assert_failure 1
    assert_output_contains "Failed: gem backup"
    assert_output_contains "No dotfiles.list in the templates"
    assert_output_contains "1 step(s) failed"
}

# --- options ------------------------------------------------------------------------

@test "backup --help prints the usage and writes nothing" {
    for flag in --help -h; do
        run "$CLI" backup "$flag"
        assert_success
        assert_output_equals "Usage: gaudi backup [output-dir]"
    done
    assert_cwd_clean
    refute_called "brew"
}

@test "backup refuses an option it does not know, with status 64" {
    run "$CLI" backup --frobnicate
    assert_failure 64
    assert_output_contains "Unknown option: --frobnicate"
    assert_output_contains "Usage: gaudi backup [output-dir]"
    assert_cwd_clean
}

@test "backup -- takes a directory whose name starts with a dash" {
    installed brew/brew.txt "jq"
    run "$CLI" backup -- "-odd"
    assert_success
    assert_file_contains "$WORK/-odd/Brewfile" 'brew "jq"'
}

# --- gems, with the real Ruby --------------------------------------------------------

@test "the gem backup's Ruby lists the gems in the user's gem directory, and only those" {
    real_ruby="$(PATH="$_REAL_PATH" type -P ruby || true)"
    [[ -n "$real_ruby" ]] || skip "ruby is not installed"
    ln -sf "$real_ruby" "$FAKEBIN/ruby"
    gem_dir="$(ruby -e 'print Gem.user_dir' 2>/dev/null)" || skip "this ruby does not run in the sandbox"
    [[ "$gem_dir" == "$HOME"/* ]] || skip "this ruby keeps user gems outside the home directory"
    for name in tmuxinator rake; do
        write_file "$gem_dir/specifications/$name-1.0.0.gemspec" <<SPEC
Gem::Specification.new do |s|
  s.name = "$name"
  s.version = "1.0.0"
  s.summary = "fixture"
  s.authors = ["Gaudi Test"]
end
SPEC
    done
    printf 'not a gemspec\n' > "$gem_dir/specifications/README"
    export GAUDI_BACKUP_MANAGERS="gem"

    run "$CLI" backup "$SANDBOX/out"
    assert_success
    assert_equal "$(grep '^  "' "$SANDBOX/out/default.gem.list.sh")" '  "rake"
  "tmuxinator"'
}
