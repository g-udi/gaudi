#!/usr/bin/env bats
# Behaviour that only exists on a real terminal: colours, and prompts that
# wait for a key. These run on a pseudo-terminal (test/support/pty); nothing
# about "is this a terminal" is stubbed here.

load ../helper

setup() {
    gaudi_sandbox darwin
    require_terminal
    export TERM="xterm-256color"
}

ESC=$'\033'

@test "terminal: a real terminal counts as interactive" {
    run on_terminal "" bash "$GAUDI_ROOT/test/support/call" gaudi::interactive
    assert_success
}

@test "terminal: messages are coloured" {
    run on_terminal "" bash "$GAUDI_ROOT/test/support/call" gaudi::error "broken"
    assert_success
    assert_output_contains "${ESC}[0;31m[ERROR]${ESC}[0m broken"

    run on_terminal "" bash "$GAUDI_ROOT/test/support/call" gaudi::success "done"
    assert_output_contains "${ESC}[0;32m[OK]${ESC}[0m done"
}

@test "terminal: no colours on a terminal that cannot show them" {
    export TERM="dumb"
    run on_terminal "" bash "$GAUDI_ROOT/test/support/call" gaudi::error "broken"
    assert_success
    assert_output_contains "[ERROR] broken"
    refute_output_contains "${ESC}["
}

@test "terminal: a prompt waits for a key and y accepts" {
    run on_terminal "y" bash "$GAUDI_ROOT/test/support/call" gaudi::confirm "Install it?" "n"
    assert_success
    assert_output_contains "Install it? [y/N]"
}

@test "terminal: n declines" {
    run on_terminal "n" bash "$GAUDI_ROOT/test/support/call" gaudi::confirm "Install it?" "y"
    assert_failure 1
}

@test "terminal: Enter takes the default" {
    run on_terminal '\n' bash "$GAUDI_ROOT/test/support/call" gaudi::confirm "Install it?" "y"
    assert_success
    run on_terminal '\n' bash "$GAUDI_ROOT/test/support/call" gaudi::confirm "Install it?" "n"
    assert_failure 1
}

@test "terminal: a wrong key is rejected and the prompt asks again" {
    run on_terminal "xy" bash "$GAUDI_ROOT/test/support/call" gaudi::confirm "Install it?" "n"
    assert_success
    assert_output_contains "Please enter a valid answer [yYnN]"
}

@test "terminal: a whole setup answered by hand installs exactly what was chosen" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    standard_templates "$GAUDI_TEMPLATES_LOCATION"

    # apps.Brewfile:   install? y   everything? n   raycast? y   kitty? n
    # core.Brewfile:   install? n
    # extras.Brewfile: install? n
    # gem list:        proceed? n
    # configs:         all? n   shared editor config? y   Finder path bar? n
    run on_terminal "ynynnnnnyn" "$GAUDI_ROOT/setup.sh" \
        --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-dotfiles --skip-cleanup
    assert_success
    assert_output_contains "Gaudi setup finished"

    assert_equal "$(cat "$MACHINE/brew/cask.txt")" "raycast"
    refute_file_exists "$MACHINE/brew/brew.txt"
    refute_file_exists "$MACHINE/brew/npm.txt"
    refute_file_exists "$MACHINE/gem.txt"
    assert_equal "$(cat "$MACHINE/configs.log")" "shared-config"
    refute_file_exists "$MACHINE/defaults.txt"
}

@test "terminal: declining everything by hand installs nothing and still finishes" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    standard_templates "$GAUDI_TEMPLATES_LOCATION"

    run on_terminal "nnnnnnn" "$GAUDI_ROOT/setup.sh" \
        --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-dotfiles --skip-cleanup
    assert_success
    assert_output_contains "Gaudi setup finished"
    assert_equal "$(machine_snapshot)" ""
    refute_file_exists "$MACHINE/configs.log"
}

@test "terminal: an SSH key is generated from typed answers" {
    # generate? Enter (default yes), then the email is typed as a line
    run on_terminal '\nsomeone@example.com\n' bash "$GAUDI_ROOT/test/support/step" configs/configure-ssh.sh
    assert_success
    assert_called "ssh-keygen -t ed25519 -C someone@example.com"
    assert_file_exists "$HOME/.ssh/id_ed25519.pub"
}
