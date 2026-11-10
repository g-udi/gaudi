#!/usr/bin/env bats
# setup.sh: option parsing, stage order and the end-of-run summary.
#
# The stages themselves are replaced by markers here (each one is tested in
# its own file), so these tests see exactly which stages ran, in which order.

load ../helper

STAGE_FLAGS="prereqs ssh templates shell-helpers software configs cleanup"

setup() {
    gaudi_sandbox darwin
    COPY="$(gaudi_copy)"
    stub_stages
}

stage() {
    printf 'printf "STAGE:%s yes=%%s\\n" "${GAUDI_ASSUME_YES}"\n' "$2" > "$COPY/$1"
}

stub_stages() {
    local os=""

    for os in osx debian; do
        stage "lib/$os/install-pre-requisits.sh" "prereqs($os)"
        stage "lib/$os/configure.sh" "configs($os)"
        stage "lib/$os/cleanup.sh" "cleanup($os)"
    done
    stage "configs/configure-ssh.sh" "ssh"
    stage "configs/configure-gaudi.sh" "templates"
    stage "lib/install-shell-helpers.sh" "shell-helpers"
    stage "lib/install-software.sh" "software"
}

# The stages that ran, in order, on one line
stages() {
    printf '%s\n' "$output" | sed -n 's/.*STAGE:\([^ ]*\).*/\1/p' | tr '\n' ' ' | sed 's/ $//'
}

@test "stages run in order; cleanup is skipped unless confirmed" {
    run "$COPY/setup.sh"
    assert_success
    assert_equal "$(stages)" "prereqs(osx) ssh templates shell-helpers software configs(osx)"
    assert_output_contains "Run package-manager cleanup now? [y/N]"
    assert_output_contains "[OK] Gaudi setup finished"
}

@test "--yes also runs the cleanup stage" {
    run "$COPY/setup.sh" --yes
    assert_success
    assert_equal "$(stages)" "prereqs(osx) ssh templates shell-helpers software configs(osx) cleanup(osx)"
}

@test "-y is the short form of --yes" {
    run "$COPY/setup.sh" -y
    assert_success
    assert_output_contains "STAGE:cleanup(osx) yes=true"
}

@test "GAUDI_ASSUME_YES=true behaves like --yes" {
    export GAUDI_ASSUME_YES="true"
    run "$COPY/setup.sh"
    assert_success
    assert_output_contains "STAGE:cleanup(osx) yes=true"
}

@test "the answer to every prompt is exported to the stages" {
    run "$COPY/setup.sh"
    assert_output_contains "STAGE:software yes=false"
    run "$COPY/setup.sh" --yes
    assert_output_contains "STAGE:software yes=true"
}

@test "each --skip flag skips exactly its own stage" {
    for flag in $STAGE_FLAGS; do
        run "$COPY/setup.sh" --yes "--skip-$flag"
        assert_success
        expected="prereqs(osx) ssh templates shell-helpers software configs(osx) cleanup(osx)"
        case "$flag" in
            prereqs) expected="${expected/prereqs(osx) /}" ;;
            configs) expected="${expected/configs(osx) /}" ;;
            cleanup) expected="${expected/ cleanup(osx)/}" ;;
            *) expected="${expected/$flag /}" ;;
        esac
        assert_equal "$(stages)" "$expected"
    done
}

@test "each GAUDI_SKIP_* variable skips exactly its own stage" {
    for variable in GAUDI_SKIP_PREREQS GAUDI_SKIP_SSH GAUDI_SKIP_TEMPLATES GAUDI_SKIP_SHELL_HELPERS GAUDI_SKIP_SOFTWARE GAUDI_SKIP_CONFIGS GAUDI_SKIP_CLEANUP; do
        run env "$variable=true" "$COPY/setup.sh" --yes
        assert_success
        marker="$(printf '%s' "${variable#GAUDI_SKIP_}" | tr 'A-Z_' 'a-z-')"
        refute_output_contains "STAGE:$marker"
        assert_equal "$(stages | wc -w | tr -d ' ')" "6"
    done
}

@test "skip flags can be combined, in any order" {
    run "$COPY/setup.sh" --skip-software --yes --skip-ssh --skip-cleanup
    assert_success
    assert_equal "$(stages)" "prereqs(osx) templates shell-helpers configs(osx)"
}

@test "with every stage skipped, setup only installs the CLI" {
    run "$COPY/setup.sh" --yes --skip-prereqs --skip-templates --skip-software --skip-configs --skip-shell-helpers --skip-ssh --skip-cleanup
    assert_success
    assert_equal "$(stages)" ""
    [[ -L "$HOME/.local/bin/gaudi" ]]
    assert_equal "$(readlink "$HOME/.local/bin/gaudi")" "$COPY/bin/gaudi"
    assert_output_contains "[OK] Gaudi setup finished"
}

@test "--help and -h print the usage and run nothing" {
    for flag in --help -h; do
        run "$COPY/setup.sh" "$flag"
        assert_success
        assert_output_contains "Usage: setup.sh [--yes]"
        assert_equal "$(stages)" ""
    done
    refute_file_exists "$HOME/.local/bin/gaudi"
}

@test "an unknown option exits 64 before anything runs" {
    run "$COPY/setup.sh" --yes --frobnicate
    assert_failure 64
    assert_output_contains "Unknown option: --frobnicate"
    assert_equal "$(stages)" ""
    refute_file_exists "$HOME/.local/bin/gaudi"
}

@test "the run starts by reporting what it detected" {
    run "$COPY/setup.sh" --skip-cleanup
    assert_output_contains "[INFO] Install root: $COPY"
    assert_output_contains "[INFO] Detected OS: osx"
    assert_output_contains "[INFO] Detected shell: zsh"
    assert_output_contains "[INFO] Shell profile: $HOME/.zshrc"
}

@test "Debian runs the Debian stages" {
    gaudi_sandbox debian
    run "$COPY/setup.sh" --yes
    assert_success
    assert_equal "$(stages)" "prereqs(debian) ssh templates shell-helpers software configs(debian) cleanup(debian)"
}

@test "an unsupported OS stops before any stage" {
    for kernel in FreeBSD SunOS; do
        export FAKE_UNAME="$kernel"
        run "$COPY/setup.sh" --yes
        assert_failure 1
        assert_output_contains "Gaudi currently automates macOS and Debian/Ubuntu. Detected: unknown"
        assert_equal "$(stages)" ""
    done
}

@test "a Linux without apt is reported as unsupported" {
    gaudi_sandbox debian
    remove_tool apt-get apt-mark
    run "$COPY/setup.sh" --yes
    assert_failure 1
    assert_output_contains "Detected: linux"
}

@test "a stage that records a failure does not stop the later stages; setup exits 1 with a summary" {
    printf 'printf "STAGE:templates\\n"\ngaudi::record_failure "templates exploded"\n' > "$COPY/configs/configure-gaudi.sh"
    run "$COPY/setup.sh" --yes
    assert_failure 1
    assert_equal "$(stages)" "prereqs(osx) ssh templates shell-helpers software configs(osx) cleanup(osx)"
    assert_output_contains "1 step(s) failed:"
    assert_output_contains "  - templates exploded"
    assert_output_contains "Gaudi setup finished with failures"
    refute_output_contains "[OK] Gaudi setup finished"
}

@test "a missing stage file is a warning and the run continues" {
    rm "$COPY/lib/install-shell-helpers.sh"
    run "$COPY/setup.sh" --yes
    assert_success
    assert_output_contains "Skipping missing step: $COPY/lib/install-shell-helpers.sh"
    assert_equal "$(stages)" "prereqs(osx) ssh templates software configs(osx) cleanup(osx)"
}

@test "GAUDI and SOURCE_LOCATION point the stages at the checkout" {
    printf 'printf "GAUDI=%%s SOURCE=%%s\\n" "$GAUDI" "$SOURCE_LOCATION"\n' > "$COPY/lib/install-software.sh"
    run "$COPY/setup.sh" --skip-cleanup
    assert_output_contains "GAUDI=$COPY SOURCE=$COPY"
}

@test "setup can be started from any directory and never writes into it" {
    mkdir -p "$SANDBOX/elsewhere"
    cd "$SANDBOX/elsewhere"
    run "$COPY/setup.sh" --yes
    assert_success
    assert_equal "$(ls -A "$SANDBOX/elsewhere")" ""
    assert_file_contains "$HOME/.zshrc" ".local/bin"
}

@test "running setup twice does not duplicate profile lines" {
    "$COPY/setup.sh" --yes >/dev/null 2>&1
    "$COPY/setup.sh" --yes >/dev/null 2>&1
    assert_equal "$(count_in_file "$HOME/.zshrc" ".local/bin")" "1"
}
