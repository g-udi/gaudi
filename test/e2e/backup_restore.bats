#!/usr/bin/env bats
# End to end: back up one machine, restore it onto another, compare them.
#
# Machine "old" is set up from a templates repository. `gaudi backup` captures
# it. The backup becomes the templates of machine "new", which starts empty.
# After `gaudi setup` on "new", both machines must hold the same software.

load ../helper

SETUP_FLAGS="--yes --skip-ssh --skip-shell-helpers"

# Set up the current machine from a templates directory, with the real setup.sh
setup_from() {
    # shellcheck disable=SC2086
    GAUDI_TEMPLATES_LOCATION="$1" "$GAUDI_ROOT/setup.sh" $SETUP_FLAGS --skip-templates </dev/null
}

backup_to() {
    "$GAUDI_ROOT/bin/gaudi" backup "$1"
}

# What Homebrew holds on a machine (taps, formulae, casks, App Store apps, ...)
brew_state() {
    machine_snapshot "$1" | sed -n '/^\[gem.txt\]/q;/^\[apt.txt\]/q;p'
}

old_mac_with_software() {
    gaudi_sandbox darwin
    use_machine old
    standard_templates "$SANDBOX/templates"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    OLD="$MACHINE"
}

@test "macOS: a backup restored on an empty machine reproduces every Homebrew-managed package" {
    old_mac_with_software
    run backup_to "$SANDBOX/backup"
    assert_success

    use_machine new
    NEW="$MACHINE"
    assert_equal "$(machine_snapshot "$NEW")" ""

    run setup_from "$SANDBOX/backup"
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"

    # Nine kinds of entries survive the round trip
    assert_equal "$(brew_state "$NEW")" "$(brew_state "$OLD")"
    for type in tap brew cask mas npm uv go cargo vscode; do
        assert_file_exists "$NEW/brew/$type.txt"
    done
    assert_file_contains "$NEW/brew/mas.txt" "Amphetamine|937984704"
    assert_file_contains "$NEW/brew/brew.txt" "example/tap/special"
}

@test "macOS: backing up the restored machine gives the same backup again" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    setup_from "$SANDBOX/backup" >/dev/null 2>&1
    run backup_to "$SANDBOX/backup-of-new"
    assert_success

    assert_equal "$(cat "$SANDBOX/backup-of-new/Brewfile")" "$(cat "$SANDBOX/backup/Brewfile")"
}

@test "macOS: the backup keeps a description above every formula and cask" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    assert_file_contains "$SANDBOX/backup/Brewfile" "# Description of jq"
    assert_file_contains "$SANDBOX/backup/Brewfile" "# Description of kitty"
    assert_file_contains "$SANDBOX/backup/Brewfile" 'mas "Amphetamine", id: 937984704'
}

@test "macOS: a backup pushed to Git restores a brand-new Mac through the one-line installer" {
    old_mac_with_software
    backup_to "$SANDBOX/remotes/my-templates/lists" >/dev/null 2>&1
    init_git_repo "$SANDBOX/remotes/my-templates"

    # A brand-new Mac: no Homebrew, no Command Line Tools, no Gaudi
    use_machine new
    NEW="$MACHINE"
    remove_tool brew
    rm "$MACHINE/clt"
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export GAUDI_REPO_URL
    export GAUDI_DEFAULT_TEMPLATES_URL="$SANDBOX/remotes/my-templates"
    # --yes also installs the shell helpers: gaudi-shell comes from a local stand-in
    gshell_remote

    run bash "$GAUDI_ROOT/install.sh" --yes </dev/null
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    assert_called "gaudi-shell-setup --silent --shell zsh"
    assert_file_exists "$HOME/.gaudi/templates/lists/Brewfile"
    assert_equal "$(brew_state "$NEW")" "$(brew_state "$OLD")"
}

@test "macOS: restoring onto a machine that already has software only adds to it" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    mkdir -p "$MACHINE/brew"
    printf 'already-here\njq\n' > "$MACHINE/brew/brew.txt"

    run setup_from "$SANDBOX/backup"
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "already-here"
    assert_file_contains "$MACHINE/brew/brew.txt" "example/tap/special"
    assert_equal "$(grep -c '^jq$' "$MACHINE/brew/brew.txt")" "1"
}

@test "macOS: a package that no longer exists does not block the rest of the restore, and a rerun finishes it" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    NEW="$MACHINE"
    export FAKE_BREW_FAIL="kitty"
    run setup_from "$SANDBOX/backup"
    assert_failure 1
    assert_output_contains "1 step(s) failed"
    assert_output_contains "rerun: brew bundle install --file=$SANDBOX/backup/Brewfile"
    # Everything except the broken cask is there
    assert_file_contains "$NEW/brew/cask.txt" "raycast"
    refute_file_contains "$NEW/brew/cask.txt" "kitty"
    assert_file_contains "$NEW/brew/vscode.txt" "esbenp.prettier-vscode"

    # Once the package is available again, the same command completes the restore
    unset FAKE_BREW_FAIL
    run setup_from "$SANDBOX/backup"
    assert_success
    assert_equal "$(brew_state "$NEW")" "$(brew_state "$OLD")"
}

@test "macOS: restoring twice leaves the machine exactly as after the first restore" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    setup_from "$SANDBOX/backup" >/dev/null 2>&1
    first="$(machine_snapshot)"
    run setup_from "$SANDBOX/backup"
    assert_success
    assert_equal "$(machine_snapshot)" "$first"
}

@test "Debian: a backup restores both the apt packages and the Homebrew packages" {
    gaudi_sandbox debian
    use_machine old
    OLD="$MACHINE"
    standard_templates "$SANDBOX/templates"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    # The old machine really has both kinds of software
    assert_file_contains "$OLD/apt.txt" "tree"
    assert_file_contains "$OLD/brew/brew.txt" "jq"

    run backup_to "$SANDBOX/backup"
    assert_success
    assert_file_exists "$SANDBOX/backup/Brewfile"
    assert_file_contains "$SANDBOX/backup/default.apt.list.sh" '"tree"'

    use_machine new
    NEW="$MACHINE"
    run setup_from "$SANDBOX/backup"
    assert_success

    assert_equal "$(sort "$NEW/apt.txt")" "$(sort "$OLD/apt.txt")"
    assert_equal "$(brew_state "$NEW")" "$(brew_state "$OLD")"
}

@test "Debian: a second backup of the restored machine matches the first" {
    gaudi_sandbox debian
    use_machine old
    standard_templates "$SANDBOX/templates"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    setup_from "$SANDBOX/backup" >/dev/null 2>&1
    backup_to "$SANDBOX/backup-of-new" >/dev/null 2>&1

    assert_equal "$(cat "$SANDBOX/backup-of-new/Brewfile")" "$(cat "$SANDBOX/backup/Brewfile")"
    assert_equal "$(cat "$SANDBOX/backup-of-new/default.apt.list.sh")" "$(cat "$SANDBOX/backup/default.apt.list.sh")"
}

@test "Debian: an apt package that disappeared does not block the rest of the restore" {
    gaudi_sandbox debian
    use_machine old
    standard_templates "$SANDBOX/templates"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    backup_to "$SANDBOX/backup" >/dev/null 2>&1

    use_machine new
    export FAKE_APT_FAIL="htop"
    run setup_from "$SANDBOX/backup"
    assert_failure 1
    assert_output_contains "htop (sudo apt-get install -y)"
    assert_file_contains "$MACHINE/apt.txt" "tree"
    refute_file_contains "$MACHINE/apt.txt" "htop"
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
}

@test "a backup taken on a Mac restores its Homebrew packages on Debian" {
    old_mac_with_software
    backup_to "$SANDBOX/backup" >/dev/null 2>&1
    old_brew="$(brew_state "$OLD")"

    gaudi_sandbox debian
    use_machine linux
    run setup_from "$SANDBOX/backup"
    assert_success
    assert_equal "$(brew_state "$MACHINE")" "$old_brew"
}

@test "Fedora: a backup restores the dnf packages and the Homebrew packages" {
    gaudi_sandbox fedora
    use_machine old
    OLD="$MACHINE"
    standard_templates "$SANDBOX/templates"
    printf '# @List: dnfList\ndnfList=( "tree" "htop" )\n' > "$SANDBOX/templates/lists/default.dnf.list.sh"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    assert_file_contains "$OLD/dnf.txt" "tree"

    run backup_to "$SANDBOX/backup"
    assert_success
    assert_file_contains "$SANDBOX/backup/default.dnf.list.sh" '"htop"'

    use_machine new
    run setup_from "$SANDBOX/backup"
    assert_success
    assert_equal "$(sort "$MACHINE/dnf.txt")" "$(sort "$OLD/dnf.txt")"
    assert_equal "$(brew_state "$MACHINE")" "$(brew_state "$OLD")"
}

@test "a backup also carries gems and dotfiles to the new machine" {
    gaudi_sandbox darwin
    use_machine old
    standard_templates "$SANDBOX/templates"
    printf '.zshrc\n.config/kitty\n' > "$SANDBOX/templates/dotfiles.list"
    setup_from "$SANDBOX/templates" >/dev/null 2>&1
    printf 'font_size 14\n' | write_file "$HOME/.config/kitty/kitty.conf"
    printf '\n# my own line\n' >> "$HOME/.zshrc"
    old_profile="$(cat "$HOME/.zshrc")"

    GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" run backup_to "$SANDBOX/backup"
    assert_success
    assert_file_contains "$SANDBOX/backup/default.gem.list.sh" '"tmuxinator"'
    assert_file_exists "$SANDBOX/backup/dotfiles/.zshrc"

    use_machine new
    run setup_from "$SANDBOX/backup"
    assert_success
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"
    assert_file_contains "$HOME/.config/kitty/kitty.conf" "font_size 14"
    assert_file_contains "$HOME/.zshrc" "# my own line"
    # The profile Gaudi itself had just written on the new machine is kept aside
    assert_file_exists "$HOME/.zshrc.gaudi-backup"
    assert_equal "$(cat "$HOME/.zshrc")" "$old_profile"
}

@test "Arch and openSUSE: a backup restores the native packages and the Homebrew packages" {
    for os in arch opensuse; do
        manager="pacman"
        [[ "$os" == "opensuse" ]] && manager="zypper"
        gaudi_sandbox "$os"
        use_machine "old-$os"
        OLD="$MACHINE"
        standard_templates "$SANDBOX/templates-$os"
        printf '# @List: %sList\n%sList=( "tree" "htop" )\n' "$manager" "$manager" > "$SANDBOX/templates-$os/lists/default.$manager.list.sh"
        setup_from "$SANDBOX/templates-$os" >/dev/null 2>&1
        assert_file_contains "$OLD/$manager.txt" "tree"

        run backup_to "$SANDBOX/backup-$os"
        assert_success
        assert_file_contains "$SANDBOX/backup-$os/default.$manager.list.sh" '"htop"'

        use_machine "new-$os"
        run setup_from "$SANDBOX/backup-$os"
        assert_success
        assert_equal "$(sort "$MACHINE/$manager.txt")" "$(sort "$OLD/$manager.txt")"
        assert_equal "$(brew_state "$MACHINE")" "$(brew_state "$OLD")"
    done
}
