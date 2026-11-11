#!/usr/bin/env bats
# bin/commands.sh and bin/colors.sh

bats_require_minimum_version 1.5.0
load ../helper

setup() {
    gaudi_sandbox darwin
}

# --- bin/commands.sh -------------------------------------------------------------

@test "run_resolved_command runs the command with its arguments" {
    run call gaudi::run_resolved_command mas install 937984704
    assert_success
    assert_called "mas install 937984704"
}

@test "run_resolved_command reports a missing command with status 127" {
    run -127 call gaudi::run_resolved_command definitely-not-installed --flag
    assert_failure 127
    assert_output_contains "Required command not found: definitely-not-installed"
}

@test "run_resolved_command returns the command's own exit status" {
    export FAKE_BREW_CLEANUP_FAIL=1
    run call gaudi::run_resolved_command brew cleanup -s
    assert_failure 1
}

@test "brew wrapper reaches a Homebrew that is not on PATH yet" {
    remove_tool brew
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    cp "$FAKES_DIR/brew" "$FAKE_BREW_PREFIX/bin/brew"

    run call brew --version
    assert_success
    assert_output_equals "Homebrew 0.0.0-fake"
}

@test "the brew wrapper forwards its arguments" {
    call brew tap example/tap
    assert_called "brew tap example/tap"
}

@test "the brew wrapper fails with 127 when Homebrew is not installed" {
    remove_tool brew
    run -127 call brew list
    assert_failure 127
}

@test "mas and npm are not wrapped: a hook can ask whether they are installed" {
    remove_tool mas npm
    run call eval 'type mas npm'
    assert_failure
}

# --- bin/colors.sh ---------------------------------------------------------------

@test "colors are empty when output is not a terminal" {
    run call eval 'printf "[%s][%s][%s][%s][%s][%s]" "$NC" "$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA"'
    assert_success
    assert_output_equals "[][][][][][]"
}

@test "every colour variable is defined and exported, so set -u never trips on one" {
    names="$(sed -n 's/^export //p' "$GAUDI_ROOT/bin/colors.sh")"
    assert_equal "$names" "NC RED GREEN YELLOW BLUE MAGENTA"
    for name in $names; do
        COLOR_NAME="$name" run call bash -c 'declare -p "$COLOR_NAME" >/dev/null'
        assert_success
    done
}

@test "on a colour terminal each colour is an escape sequence that printf %b understands" {
    require_terminal
    run on_terminal "" env TERM=xterm-256color bash "$GAUDI_ROOT/test/support/call" eval 'printf "%b|%b|%b|%b|%b|%b" "$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA" "$NC" | cat -v'
    assert_success
    assert_output_contains "^[[0;31m|^[[0;32m|^[[0;33m|^[[0;34m|^[[0;35m|^[[0m"
}

@test "colors load without TERM and without tput" {
    remove_tool tput
    unset TERM
    run call eval 'printf "loaded"'
    assert_success
    assert_output_equals "loaded"
}

@test "colors load when TERM is set to something tput cannot handle" {
    export TERM="not-a-real-terminal"
    run call eval 'printf "loaded"'
    assert_success
    assert_output_equals "loaded"
}
