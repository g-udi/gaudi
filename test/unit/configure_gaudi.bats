#!/usr/bin/env bats
# configs/configure-gaudi.sh: cloning and updating the templates repository

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    REMOTE="$SANDBOX/remotes/templates"
    mkdir -p "$REMOTE"
    printf 'brew "jq"\n' > "$REMOTE/Brewfile"
    init_git_repo "$REMOTE"
    export GAUDI_DEFAULT_TEMPLATES_URL="$REMOTE"
}

templates_step() {
    step configs/configure-gaudi.sh
}

# Add a commit to the remote templates repository
publish() {
    printf '%s\n' "$2" > "$REMOTE/$1"
    git -C "$REMOTE" add -A
    git -C "$REMOTE" commit -q -m "update"
}

@test "templates are cloned from the default repository when none exist" {
    run templates_step </dev/null
    assert_success
    assert_output_contains "Enter the Gaudi templates Git URL [$REMOTE]:"
    assert_file_exists "$GAUDI_TEMPLATES_LOCATION/.git"
    assert_file_contains "$GAUDI_TEMPLATES_LOCATION/Brewfile" 'brew "jq"'
}

@test "a typed repository URL is cloned instead of the default" {
    mkdir -p "$SANDBOX/remotes/mine"
    printf 'brew "mine"\n' > "$SANDBOX/remotes/mine/Brewfile"
    init_git_repo "$SANDBOX/remotes/mine"

    run templates_step <<< "$SANDBOX/remotes/mine"
    assert_success
    assert_file_contains "$GAUDI_TEMPLATES_LOCATION/Brewfile" 'brew "mine"'
}

@test "an empty templates directory is replaced by the clone" {
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
    run templates_step </dev/null
    assert_success
    assert_file_exists "$GAUDI_TEMPLATES_LOCATION/.git"
}

@test "missing parent directories are created for the clone" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/a/b/c/templates"
    run templates_step </dev/null
    assert_success
    assert_file_exists "$GAUDI_TEMPLATES_LOCATION/Brewfile"
}

@test "templates default to \$GAUDI/templates" {
    unset GAUDI_TEMPLATES_LOCATION
    export GAUDI="$SANDBOX/gaudi-home"
    mkdir -p "$GAUDI"
    run templates_step </dev/null
    assert_success
    assert_file_exists "$GAUDI/templates/Brewfile"
}

@test "an existing checkout is updated by default" {
    git clone -q "$REMOTE" "$GAUDI_TEMPLATES_LOCATION"
    publish "new.Brewfile" 'brew "new"'

    run templates_step </dev/null
    assert_success
    assert_output_contains "Update existing templates at $GAUDI_TEMPLATES_LOCATION? [Y/n]"
    assert_file_exists "$GAUDI_TEMPLATES_LOCATION/new.Brewfile"
}

@test "an existing checkout is left as it is when the update is declined" {
    git clone -q "$REMOTE" "$GAUDI_TEMPLATES_LOCATION"
    publish "new.Brewfile" 'brew "new"'
    interactive

    run templates_step <<< "n"
    assert_success
    refute_file_exists "$GAUDI_TEMPLATES_LOCATION/new.Brewfile"
}

@test "a failed update is a warning and the existing templates are used" {
    git clone -q "$REMOTE" "$GAUDI_TEMPLATES_LOCATION"
    # Local edit that conflicts with the next remote commit
    printf 'brew "local-edit"\n' > "$GAUDI_TEMPLATES_LOCATION/Brewfile"
    publish "Brewfile" 'brew "remote-edit"'

    run templates_step </dev/null
    assert_success
    assert_output_contains "Could not update templates"
    assert_file_contains "$GAUDI_TEMPLATES_LOCATION/Brewfile" 'brew "local-edit"'
}

@test "a non-Git templates directory with files is used and never deleted" {
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
    printf 'brew "handmade"\n' > "$GAUDI_TEMPLATES_LOCATION/Brewfile"

    run templates_step </dev/null
    assert_success
    assert_output_contains "Using existing non-Git templates directory: $GAUDI_TEMPLATES_LOCATION"
    assert_file_contains "$GAUDI_TEMPLATES_LOCATION/Brewfile" 'brew "handmade"'
    refute_file_exists "$GAUDI_TEMPLATES_LOCATION/.git"
}

@test "an unreachable repository is recorded as a failure instead of looping" {
    export GAUDI_DEFAULT_TEMPLATES_URL="$SANDBOX/remotes/missing"
    run templates_step </dev/null
    assert_failure 1
    assert_output_contains "Unable to access repository: $SANDBOX/remotes/missing"
    assert_output_contains "templates: no reachable repository"
    refute_file_exists "$GAUDI_TEMPLATES_LOCATION"
}

@test "the templates location is exported for the following steps" {
    printf 'printf "location=%%s\\n" "$(bash -c "printf %%s \"\\$GAUDI_TEMPLATES_LOCATION\"")"\n' > "$SANDBOX/probe.sh"
    cp "$SANDBOX/probe.sh" "$GAUDI_ROOT/../.gaudi-probe-$$.sh" 2>/dev/null || true
    rm -f "$GAUDI_ROOT/../.gaudi-probe-$$.sh"

    run call eval 'get_os; get_shell_type; source "$SOURCE_LOCATION/configs/configure-gaudi.sh" </dev/null >/dev/null 2>&1; bash -c "printf %s \"\$GAUDI_TEMPLATES_LOCATION\""'
    assert_success
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION"
}
