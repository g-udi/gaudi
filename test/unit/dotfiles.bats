#!/usr/bin/env bats
# Dotfiles: `gaudi backup` copies the files named in dotfiles.list, and the
# lib/install-dotfiles.sh stage puts <templates>/dotfiles back into HOME.

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
    export GAUDI_BACKUP_MANAGERS="dotfiles"
}

backup() {
    "$GAUDI_ROOT/bin/gaudi" backup "$SANDBOX/out"
}

restore() {
    step lib/install-dotfiles.sh
}

home_file() {
    write_file "$HOME/$1"
}

template_dotfile() {
    write_file "$GAUDI_TEMPLATES_LOCATION/dotfiles/$1"
}

# --- backup ----------------------------------------------------------------------

@test "backup copies the listed files and directories, keeping their layout" {
    printf 'export EDITOR=vim\n' | home_file ".zshrc"
    printf 'font_size 14\n' | home_file ".config/kitty/kitty.conf"
    printf 'theme dark\n' | home_file ".config/kitty/themes/dark.conf"
    printf 'not listed\n' | home_file ".secret"
    printf '# my dotfiles\n.zshrc\n  .config/kitty   # the whole directory\n\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"

    run backup
    assert_success
    assert_output_contains "Copied 2 dotfile(s) to $SANDBOX/out/dotfiles"
    assert_file_contains "$SANDBOX/out/dotfiles/.zshrc" "export EDITOR=vim"
    assert_file_contains "$SANDBOX/out/dotfiles/.config/kitty/kitty.conf" "font_size 14"
    assert_file_contains "$SANDBOX/out/dotfiles/.config/kitty/themes/dark.conf" "theme dark"
    refute_file_exists "$SANDBOX/out/dotfiles/.secret"
}

@test "backup without a dotfiles.list copies nothing" {
    printf 'x\n' | home_file ".zshrc"
    run backup
    assert_success
    assert_output_contains "No dotfiles.list in the templates"
    refute_file_exists "$SANDBOX/out/dotfiles"
}

@test "backup skips listed files that do not exist, with a warning" {
    printf 'x\n' | home_file ".zshrc"
    printf '.zshrc\n.vimrc\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_output_contains "Skipping '.vimrc': not found in $HOME"
    assert_file_exists "$SANDBOX/out/dotfiles/.zshrc"
}

@test "backup refuses paths outside the home directory" {
    printf 'outside\n' > "$SANDBOX/outside.txt"
    printf '/etc/hosts\n../outside.txt\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_output_contains "Skipping '/etc/hosts'"
    assert_output_contains "Skipping '../outside.txt'"
    assert_output_contains "Copied 0 dotfile(s)"
}

@test "backup refuses the home directory itself, however it is written" {
    printf 'secret\n' | home_file ".ssh/id_ed25519"
    printf 'x\n' | home_file ".zshrc"
    printf '.\n./\n./.\n .  \n././\n.zshrc\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_output_contains "Skipping '.' in"
    assert_output_contains "Skipping './' in"
    assert_output_contains "Skipping './.' in"
    assert_output_contains "Skipping '././' in"
    assert_output_contains "Copied 1 dotfile(s)"
    assert_equal "$(ls -A "$SANDBOX/out/dotfiles")" ".zshrc"
}

@test "backup refuses a path that leaves the home directory through a symlink" {
    mkdir -p "$SANDBOX/elsewhere"
    printf 'outside\n' > "$SANDBOX/elsewhere/file.txt"
    ln -s "$SANDBOX/elsewhere" "$HOME/link"
    ln -s "$HOME" "$HOME/.config-link"
    printf 'link/file.txt\n.config-link/.\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_output_contains "Skipping 'link/file.txt'"
    assert_output_contains "Copied 1 dotfile(s)"
    # The link to the home directory is copied as a link, never followed
    [[ -L "$SANDBOX/out/dotfiles/.config-link" ]]
    refute_file_exists "$SANDBOX/out/dotfiles/link"
}

@test "backup tidies ./ and trailing slashes instead of refusing them" {
    printf 'x\n' | home_file ".zshrc"
    printf 'y\n' | home_file ".config/kitty/kitty.conf"
    printf './.zshrc\n.config/kitty/\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_output_contains "Copied 2 dotfile(s)"
    assert_file_exists "$SANDBOX/out/dotfiles/.zshrc"
    assert_file_exists "$SANDBOX/out/dotfiles/.config/kitty/kitty.conf"
}

@test "backing up again replaces the previous copy, including files that were removed" {
    printf 'one\n' | home_file ".config/app/a.conf"
    printf 'two\n' | home_file ".config/app/b.conf"
    printf '.config/app\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    backup >/dev/null 2>&1
    rm "$HOME/.config/app/b.conf"
    printf 'changed\n' > "$HOME/.config/app/a.conf"

    run backup
    assert_success
    assert_file_contains "$SANDBOX/out/dotfiles/.config/app/a.conf" "changed"
    refute_file_exists "$SANDBOX/out/dotfiles/.config/app/b.conf"
}

@test "dotfiles are part of a default backup" {
    unset GAUDI_BACKUP_MANAGERS
    printf 'x\n' | home_file ".zshrc"
    printf '.zshrc\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_file_exists "$SANDBOX/out/dotfiles/.zshrc"
    assert_file_exists "$SANDBOX/out/Brewfile"
}

@test "names with spaces are backed up" {
    printf 'x\n' | home_file "Library/Application Support/App/settings.json"
    printf 'Library/Application Support/App/settings.json\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    run backup
    assert_success
    assert_file_exists "$SANDBOX/out/dotfiles/Library/Application Support/App/settings.json"
}

# --- restore ---------------------------------------------------------------------

@test "restore does nothing without a dotfiles directory in the templates" {
    run restore
    assert_success
    assert_output_equals "STEP-DONE"
}

@test "restore is declined by default and changes nothing" {
    printf 'new\n' | template_dotfile ".zshrc"
    run restore
    assert_success
    assert_output_contains "$HOME/.zshrc (new)"
    assert_output_contains "Restore these 1 dotfile(s) into $HOME? [y/N]"
    refute_file_exists "$HOME/.zshrc"
}

@test "restore copies new files into place, creating directories" {
    printf 'export EDITOR=vim\n' | template_dotfile ".zshrc"
    printf 'font_size 14\n' | template_dotfile ".config/kitty/kitty.conf"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_file_contains "$HOME/.zshrc" "export EDITOR=vim"
    assert_file_contains "$HOME/.config/kitty/kitty.conf" "font_size 14"
}

@test "restore keeps a different existing file as <file>.gaudi-backup" {
    printf 'mine\n' | home_file ".zshrc"
    printf 'from templates\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_output_contains "$HOME/.zshrc (replaces the existing file)"
    assert_file_contains "$HOME/.zshrc" "from templates"
    assert_file_contains "$HOME/.zshrc.gaudi-backup" "mine"
}

@test "restore never overwrites an earlier .gaudi-backup" {
    printf 'first\n' | home_file ".zshrc.gaudi-backup"
    printf 'second\n' | home_file ".zshrc"
    printf 'from templates\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_file_contains "$HOME/.zshrc.gaudi-backup" "first"
    assert_equal "$(cat "$HOME"/.zshrc.gaudi-backup.*)" "second"
}

@test "restore leaves identical files alone and does not ask" {
    printf 'same\n' | home_file ".zshrc"
    printf 'same\n' | template_dotfile ".zshrc"
    run restore
    assert_success
    assert_output_contains "Dotfiles are already in place"
    refute_output_contains "Restore these"
    refute_file_exists "$HOME/.zshrc.gaudi-backup"
}

@test "restore only touches the files that differ" {
    printf 'same\n' | home_file ".vimrc"
    printf 'same\n' | template_dotfile ".vimrc"
    printf 'new\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_output_contains "Restore these 1 dotfile(s)"
    refute_file_exists "$HOME/.vimrc.gaudi-backup"
}

@test "restoring twice changes nothing the second time" {
    printf 'new\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true"
    restore >/dev/null 2>&1
    run restore
    assert_success
    assert_output_contains "Dotfiles are already in place"
    refute_file_exists "$HOME/.zshrc.gaudi-backup"
}

@test "a dry run only names the files" {
    printf 'new\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true" GAUDI_DRY_RUN="true"
    run restore
    assert_success
    assert_output_contains "DRY RUN: dotfile $HOME/.zshrc"
    refute_file_exists "$HOME/.zshrc"
}

@test "a file that cannot be written is recorded and the rest are restored" {
    printf 'a\n' | template_dotfile ".blocked/a.conf"
    printf 'b\n' | template_dotfile ".zshrc"
    printf 'a file where a directory is needed\n' > "$HOME/.blocked"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_failure 1
    assert_output_contains "dotfile $HOME/.blocked/a.conf"
    assert_file_contains "$HOME/.zshrc" "b"
}

@test "restore refuses a file that would land outside the home directory" {
    mkdir -p "$SANDBOX/elsewhere"
    ln -s "$SANDBOX/elsewhere" "$HOME/link"
    printf 'x\n' | template_dotfile "link/file.txt"
    printf 'y\n' | template_dotfile ".zshrc"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_output_contains "Skipping $GAUDI_TEMPLATES_LOCATION/dotfiles/link/file.txt"
    assert_output_contains "Restore these 1 dotfile(s)"
    assert_file_exists "$HOME/.zshrc"
    refute_file_exists "$SANDBOX/elsewhere/file.txt"
}

@test "backup then restore brings the files back on another machine" {
    printf 'export EDITOR=vim\n' | home_file ".zshrc"
    printf 'font_size 14\n' | home_file ".config/kitty/kitty.conf"
    printf '.zshrc\n.config/kitty\n' > "$GAUDI_TEMPLATES_LOCATION/dotfiles.list"
    backup >/dev/null 2>&1

    use_machine new
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/out" GAUDI_ASSUME_YES="true"
    run restore
    assert_success
    assert_file_contains "$HOME/.zshrc" "export EDITOR=vim"
    assert_file_contains "$HOME/.config/kitty/kitty.conf" "font_size 14"
}

@test "identical files are recognised on a machine without cmp" {
    remove_tool cmp
    printf 'same\n' | home_file ".zshrc"
    printf 'same\n' | template_dotfile ".zshrc"
    printf 'changed\n' | home_file ".vimrc"
    printf 'from templates\n' | template_dotfile ".vimrc"
    export GAUDI_ASSUME_YES="true"

    run restore
    assert_success
    assert_output_contains "Restore these 1 dotfile(s)"
    refute_file_exists "$HOME/.zshrc.gaudi-backup"
    assert_file_contains "$HOME/.vimrc" "from templates"
}
