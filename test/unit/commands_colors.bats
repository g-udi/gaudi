#!/usr/bin/env bats
# bin/commands.sh and bin/colors.sh

bats_require_minimum_version 1.5.0
load ../helper

setup() {
    gaudi_sandbox darwin
}

# --- bin/commands.sh -------------------------------------------------------------

@test "resolved_command_path prints where a command lives" {
    run call gaudi::resolved_command_path brew
    assert_success
    assert_output_equals "$FAKEBIN/brew"
}

@test "resolved_command_path fails for a missing command" {
    run call gaudi::resolved_command_path definitely-not-installed
    assert_failure
}

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

@test "brew, mas and npm wrappers forward their arguments" {
    call brew tap example/tap
    call mas list
    call npm install -g eslint
    assert_called "brew tap example/tap"
    assert_called "mas list"
    assert_called "npm install -g eslint"
}

@test "a wrapper for a tool that is not installed fails with 127" {
    remove_tool mas
    run -127 call mas list
    assert_failure 127
}

# --- bin/colors.sh ---------------------------------------------------------------

@test "colors are empty when output is not a terminal" {
    run call eval 'printf "[%s][%s][%s]" "$RED" "$BOLD_GREEN" "$NC"'
    assert_success
    assert_output_equals "[][][]"
}

@test "every colour variable is defined, so set -u never trips on one" {
    names="$(grep -o 'export [A-Z_]*=' "$GAUDI_ROOT/bin/colors.sh" | sed 's/export //; s/=//' | sort -u)"
    [[ -n "$names" ]]
    for name in $names; do
        COLOR_NAME="$name" run call eval 'declare -p "$COLOR_NAME" >/dev/null'
        assert_success
    done
}

@test "colors load without TERM and without tput" {
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
