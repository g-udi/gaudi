#!/usr/bin/env bats
# bin/helpers.sh: the functions that ask the user something

load ../helper

setup() {
    gaudi_sandbox darwin
}

stdout_of() { "$@" 2>/dev/null; }

# --- gaudi::read_answer ----------------------------------------------------------------

@test "gaudi::read_answer: --yes answers y without reading input" {
    export GAUDI_ASSUME_YES="true"
    run call gaudi::read_answer "yYnN" "n" <<< "n"
    assert_success
    assert_output_equals "y"
}

@test "gaudi::read_answer: --yes never answers outside the allowed characters" {
    export GAUDI_ASSUME_YES="true"
    run call gaudi::read_answer "abc" "b" <<< "c"
    assert_success
    assert_output_equals "b"

    # No default: the first allowed character
    run call gaudi::read_answer "abc" "" <<< "c"
    assert_success
    assert_output_equals "a"
}

@test "gaudi::read_answer: without a terminal the default is used" {
    run call gaudi::read_answer "yYnN" "y" <<< "n"
    assert_output_equals "y"
}

@test "gaudi::read_answer: without a terminal and without a default the answer is n" {
    run call gaudi::read_answer "yYnN" "" <<< "y"
    assert_output_equals "n"
}

@test "gaudi::read_answer: a valid key is returned" {
    interactive
    run stdout_of call gaudi::read_answer "yYnN" "n" <<< "y"
    assert_output_equals "y"
}

@test "gaudi::read_answer: Enter picks the default" {
    interactive
    run stdout_of call gaudi::read_answer "yYnN" "y" <<< ""
    assert_output_equals "y"
}

@test "gaudi::read_answer: an invalid key is rejected and asked again" {
    interactive
    run call gaudi::read_answer "yYnN" "n" <<< "xy"
    assert_success
    assert_output_contains "Please enter a valid answer [yYnN]"
    [[ "$output" == *y ]]
}

@test "gaudi::read_answer: end of input falls back to the default instead of looping" {
    interactive
    run stdout_of call gaudi::read_answer "yYnN" "y" </dev/null
    assert_success
    assert_output_equals "y"
}

@test "gaudi::read_answer: end of input without a default answers n" {
    interactive
    run stdout_of call gaudi::read_answer "yYnN" "" </dev/null
    assert_success
    assert_output_equals "n"
}

@test "gaudi::read_answer: only the listed keys are accepted" {
    interactive
    run stdout_of call gaudi::read_answer "ab" "" <<< "yb"
    assert_output_equals "b"
}

# --- gaudi::confirm --------------------------------------------------------------

@test "confirm: y is yes" {
    interactive
    run call gaudi::confirm "Install it?" "n" <<< "y"
    assert_success
    assert_output_contains "Install it? [y/N]"
}

@test "confirm: Y is yes" {
    interactive
    run call gaudi::confirm "Install it?" "n" <<< "Y"
    assert_success
}

@test "confirm: n is no" {
    interactive
    run call gaudi::confirm "Install it?" "y" <<< "n"
    assert_failure
    assert_output_contains "Install it? [Y/n]"
}

@test "confirm: the default is no when none is given" {
    run call gaudi::confirm "Install it?"
    assert_failure
    assert_output_contains "[y/N]"
}

@test "confirm: a default of y is taken without a terminal" {
    run call gaudi::confirm "Install it?" "y"
    assert_success
}

@test "confirm: --yes accepts everything" {
    export GAUDI_ASSUME_YES="true"
    run call gaudi::confirm "Install it?" "n"
    assert_success
}

# --- gaudi::read_email --------------------------------------------------------------------

@test "gaudi::read_email: a valid address is returned" {
    run stdout_of call gaudi::read_email <<< "someone@example.com"
    assert_success
    assert_output_equals "someone@example.com"
}

@test "gaudi::read_email: invalid addresses are rejected until a valid one arrives" {
    run call gaudi::read_email <<< $'not-an-email\nmissing@tld\nsomeone@example.com'
    assert_success
    assert_output_contains "Please enter a valid email address"
    [[ "$output" == *someone@example.com ]]
}

@test "gaudi::read_email: end of input fails instead of looping forever" {
    run call gaudi::read_email </dev/null
    assert_failure
}

@test "gaudi::read_email: only invalid input then end of input fails" {
    run call gaudi::read_email <<< "nope"
    assert_failure
    assert_output_contains "Please enter a valid email address"
}

# --- gaudi::read_git_url --------------------------------------------------------------------

@test "gaudi::read_git_url: an empty answer takes the default repository" {
    mkdir -p "$SANDBOX/remotes/templates"
    init_git_repo "$SANDBOX/remotes/templates"

    run stdout_of call gaudi::read_git_url "$SANDBOX/remotes/templates" <<< ""
    assert_success
    assert_output_equals "$SANDBOX/remotes/templates"
}

@test "gaudi::read_git_url: a typed repository is returned" {
    mkdir -p "$SANDBOX/remotes/default" "$SANDBOX/remotes/mine"
    init_git_repo "$SANDBOX/remotes/default"
    init_git_repo "$SANDBOX/remotes/mine"

    run stdout_of call gaudi::read_git_url "$SANDBOX/remotes/default" <<< "$SANDBOX/remotes/mine"
    assert_output_equals "$SANDBOX/remotes/mine"
}

@test "gaudi::read_git_url: an unreachable repository is asked again" {
    mkdir -p "$SANDBOX/remotes/mine"
    init_git_repo "$SANDBOX/remotes/mine"

    run call gaudi::read_git_url "$SANDBOX/remotes/missing" <<< $'/no/such/repo\n'"$SANDBOX/remotes/mine"
    assert_success
    assert_output_contains "Unable to access repository: /no/such/repo"
    [[ "$output" == *"$SANDBOX/remotes/mine" ]]
}

@test "gaudi::read_git_url: end of input with an unreachable default fails instead of looping" {
    run call gaudi::read_git_url "$SANDBOX/remotes/missing" </dev/null
    assert_failure
    assert_output_contains "Unable to access repository: $SANDBOX/remotes/missing"
}

@test "gaudi::read_git_url: end of input with a reachable default uses it" {
    mkdir -p "$SANDBOX/remotes/templates"
    init_git_repo "$SANDBOX/remotes/templates"

    run stdout_of call gaudi::read_git_url "$SANDBOX/remotes/templates" </dev/null
    assert_success
    assert_output_equals "$SANDBOX/remotes/templates"
}

@test "gaudi::read_git_url: --yes takes the default without reading the keyboard" {
    mkdir -p "$SANDBOX/remotes/templates" "$SANDBOX/remotes/typed"
    init_git_repo "$SANDBOX/remotes/templates"
    init_git_repo "$SANDBOX/remotes/typed"
    export GAUDI_ASSUME_YES="true"
    interactive

    run stdout_of call gaudi::read_git_url "$SANDBOX/remotes/templates" <<< "$SANDBOX/remotes/typed"
    assert_success
    assert_output_equals "$SANDBOX/remotes/templates"
}

@test "gaudi::read_git_url: --yes with an unreachable default fails instead of asking" {
    mkdir -p "$SANDBOX/remotes/typed"
    init_git_repo "$SANDBOX/remotes/typed"
    export GAUDI_ASSUME_YES="true"
    interactive

    run call gaudi::read_git_url "$SANDBOX/remotes/missing" <<< "$SANDBOX/remotes/typed"
    assert_failure
    assert_output_contains "Unable to access repository: $SANDBOX/remotes/missing"
    refute_output_contains "Enter a reachable Git URL"
}

# --- the names from before the gaudi:: prefix ------------------------------------------

@test "read_answer, read_email and read_git_url still work under their old names" {
    mkdir -p "$SANDBOX/remotes/templates"
    init_git_repo "$SANDBOX/remotes/templates"
    interactive

    run stdout_of call read_answer "yYnN" "n" <<< "y"
    assert_output_equals "y"
    run stdout_of call read_email <<< "me@example.com"
    assert_output_equals "me@example.com"
    run stdout_of call read_git_url "$SANDBOX/remotes/templates" <<< ""
    assert_output_equals "$SANDBOX/remotes/templates"
}
