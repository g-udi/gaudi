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
    assert_called "brew bundle dump --describe --force --file=$SANDBOX/out/Brewfile"
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
