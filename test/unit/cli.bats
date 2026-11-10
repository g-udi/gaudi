#!/usr/bin/env bats
# bin/gaudi: the command-line entry point

load ../helper

setup() {
    gaudi_sandbox darwin
    CLI="$GAUDI_ROOT/bin/gaudi"
}

# A copy of the checkout whose setup.sh and backup.sh only report how they
# were called, to test what the CLI hands over to them.
stub_checkout() {
    local copy=""

    copy="$(gaudi_copy)"
    printf '#!/usr/bin/env bash\nprintf "setup-args:%%s\\n" "$*"\nprintf "GAUDI=%%s\\n" "$GAUDI"\n' > "$copy/setup.sh"
    printf '#!/usr/bin/env bash\nprintf "backup-args:%%s\\n" "$*"\n' > "$copy/backup.sh"
    chmod +x "$copy/setup.sh" "$copy/backup.sh"
    printf "%s" "$copy"
}

# --- help, version, unknown -----------------------------------------------------

@test "no arguments prints the usage" {
    run "$CLI"
    assert_success
    assert_output_contains "gaudi - reproducible workstation bootstrapper"
    assert_output_contains "gaudi setup"
    assert_output_contains "gaudi backup [output-dir]"
    assert_output_contains "gaudi doctor"
}

@test "help, -h and --help print the usage" {
    for flag in help -h --help; do
        run "$CLI" "$flag"
        assert_success
        assert_output_contains "Usage:"
    done
}

@test "version prints the Git description of the checkout" {
    run "$CLI" version
    assert_success
    [[ -n "$output" ]]
    assert_equal "$output" "$(git -C "$GAUDI_ROOT" describe --always --dirty)"
}

@test "version prints unknown outside a Git checkout" {
    copy="$(gaudi_copy)"
    run "$copy/bin/gaudi" version
    assert_success
    assert_output_equals "unknown"
}

@test "an unknown command prints an error and the usage, and exits 64" {
    run "$CLI" bogus
    assert_failure 64
    assert_output_contains "[ERROR] Unknown command: bogus"
    assert_output_contains "Usage:"
}

# --- handing over to setup and backup ---------------------------------------------

@test "setup forwards every argument to setup.sh" {
    copy="$(stub_checkout)"
    run "$copy/bin/gaudi" setup --yes --skip-ssh "with space"
    assert_success
    assert_output_contains "setup-args:--yes --skip-ssh with space"
}

@test "setup runs the real setup.sh" {
    run "$CLI" setup --help
    assert_success
    assert_output_contains "Usage: setup.sh"
}

@test "backup forwards the output directory to backup.sh" {
    copy="$(stub_checkout)"
    run "$copy/bin/gaudi" backup "$SANDBOX/out dir"
    assert_success
    assert_output_contains "backup-args:$SANDBOX/out dir"
}

@test "GAUDI is exported to the scripts the CLI starts" {
    copy="$(stub_checkout)"
    run "$copy/bin/gaudi" setup
    assert_output_contains "GAUDI=$copy"
}

# --- locating the checkout ---------------------------------------------------------

@test "the CLI works through an absolute symlink" {
    mkdir -p "$HOME/.local/bin"
    ln -s "$CLI" "$HOME/.local/bin/gaudi"
    run "$HOME/.local/bin/gaudi" setup --help
    assert_success
    assert_output_contains "Usage: setup.sh"
}

@test "the CLI works through a relative symlink" {
    copy="$(stub_checkout)"
    mkdir -p "$SANDBOX/links"
    ( cd "$SANDBOX/links" && ln -s "../gaudi-copy/bin/gaudi" gaudi )
    run "$SANDBOX/links/gaudi" setup
    assert_success
    assert_output_contains "GAUDI=$copy"
}

@test "the CLI works through a chain of symlinks" {
    copy="$(stub_checkout)"
    mkdir -p "$SANDBOX/one" "$SANDBOX/two"
    ln -s "$copy/bin/gaudi" "$SANDBOX/one/gaudi"
    ln -s "$SANDBOX/one/gaudi" "$SANDBOX/two/gaudi"
    run "$SANDBOX/two/gaudi" setup
    assert_success
    assert_output_contains "GAUDI=$copy"
}

@test "the CLI works when called by name from PATH" {
    mkdir -p "$HOME/.local/bin"
    ln -s "$CLI" "$HOME/.local/bin/gaudi"
    export PATH="$HOME/.local/bin:$PATH"
    run gaudi help
    assert_success
    assert_output_contains "Usage:"
}

@test "a GAUDI variable that points at a real checkout is honoured" {
    copy="$(stub_checkout)"
    export GAUDI="$copy"
    run "$CLI" setup
    assert_output_contains "GAUDI=$copy"
}

@test "a GAUDI variable that points nowhere useful is ignored" {
    export GAUDI="$SANDBOX/not-a-checkout"
    run "$CLI" setup --help
    assert_success
    assert_output_contains "Usage: setup.sh"
}

# --- doctor --------------------------------------------------------------------------

@test "doctor reports the checkout, OS, shell and templates" {
    run "$CLI" doctor
    assert_success
    assert_output_contains "[INFO] Gaudi: $GAUDI_ROOT"
    assert_output_contains "[INFO] OS: osx"
    assert_output_contains "[INFO] Shell: zsh ($HOME/.zshrc)"
    assert_output_contains "[INFO] Templates: $GAUDI_ROOT/templates"
    assert_output_contains "[OK] git is available"
    assert_output_contains "[OK] Homebrew is available"
    assert_output_contains "[OK] Doctor completed"
}

@test "doctor counts the Brewfiles in the templates" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    printf 'brew "a"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/Brewfile"
    printf 'brew "b"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
    printf 'x\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/notes.txt"

    run "$CLI" doctor
    assert_success
    assert_output_contains "[INFO] Templates: $SANDBOX/templates"
    assert_output_contains "[INFO] Brewfiles found: 2"
}

@test "doctor warns when the templates are not cloned yet" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/no-templates"
    run "$CLI" doctor
    assert_success
    assert_output_contains "Templates are not cloned yet: run gaudi setup"
}

@test "doctor fails when git is missing" {
    remove_tool git
    run "$CLI" doctor
    assert_failure 1
    assert_output_contains "[ERROR] git is missing"
    refute_output_contains "Doctor completed"
}

@test "doctor warns, but passes, when Homebrew is missing" {
    remove_tool brew
    run "$CLI" doctor
    assert_success
    assert_output_contains "Homebrew is not installed yet"
}

@test "doctor warns about an OS that is not automated" {
    export FAKE_UNAME="FreeBSD"
    run "$CLI" doctor
    assert_success
    assert_output_contains "This OS is detected but not fully automated yet: unknown"
}

@test "doctor changes nothing on the machine" {
    run "$CLI" doctor
    assert_success
    assert_cwd_clean
    refute_file_exists "$HOME/.zshrc"
    refute_file_exists "$HOME/.local"
}

@test "check forwards its arguments to check.sh" {
    copy="$(stub_checkout)"
    printf '#!/usr/bin/env bash\nprintf "check-args:%%s\\n" "$*"\n' > "$copy/check.sh"
    chmod +x "$copy/check.sh"
    run "$copy/bin/gaudi" check "$SANDBOX/my templates" --online
    assert_success
    assert_output_contains "check-args:$SANDBOX/my templates --online"
}

@test "the usage lists check" {
    run "$CLI" help
    assert_output_contains "gaudi check [templates-dir] [--online]"
}
