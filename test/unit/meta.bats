#!/usr/bin/env bats
# Lint and completeness: syntax, ShellCheck, and checks that the suite and the
# documentation keep up with the code.

setup() {
    ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    cd "$ROOT" || return 1
}

# Every shell script in the repository (templates and vendored test tools excluded)
shell_files() {
    {
        find . -type f -name '*.sh' -not -path './templates/*' -not -path './test/deps/*' -not -path './.git/*'
        printf '%s\n' ./bin/gaudi ./test/run ./test/fakes/brew ./test/fakes/tool ./test/support/call ./test/support/step ./test/support/run-file ./test/helper.bash
    } | sort -u
}

# The scripts that make up Gaudi itself
source_files() {
    find ./bin ./lib ./configs -type f \( -name '*.sh' -o -name 'gaudi' \) | sort
    printf '%s\n' ./install.sh ./setup.sh ./backup.sh ./check.sh
}

test_files() {
    find ./test/unit ./test/e2e -type f -name '*.bats'
}

@test "every script parses with the bash under test" {
    while IFS= read -r file; do
        "${GAUDI_TEST_BASH:-bash}" -n "$file" || { echo "syntax error: $file"; return 1; }
    done < <(shell_files)
}

@test "every script parses with the system bash (3.2 on macOS)" {
    [[ -x /bin/bash ]] || skip "no /bin/bash"
    while IFS= read -r file; do
        /bin/bash -n "$file" || { echo "syntax error under /bin/bash: $file"; return 1; }
    done < <(shell_files)
}

@test "ShellCheck finds no warnings" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck is not installed"
    # shellcheck disable=SC2046
    shellcheck -x -S warning $(shell_files)
}

@test "ShellCheck finds no warnings in the bats files" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck is not installed"
    # shellcheck disable=SC2046
    shellcheck -S warning --shell=bats $(test_files)
}

@test "entry points and test tools are executable" {
    for file in install.sh setup.sh backup.sh check.sh bin/gaudi test/run test/fakes/brew test/fakes/tool test/support/call test/support/step test/support/run-file test/support/pty test/real/linux.sh test/real/macos.sh; do
        [[ -x "$file" ]] || { echo "not executable: $file"; return 1; }
    done
}

@test "the pseudo-terminal helper is valid Python" {
    command -v python3 >/dev/null 2>&1 || skip "python3 is not installed"
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' test/support/pty
}

@test "every script has a bash shebang" {
    while IFS= read -r file; do
        [[ "$(head -n 1 "$file")" == "#!/usr/bin/env bash" ]] || { echo "unexpected shebang: $file"; return 1; }
    done < <(shell_files)
}

@test "no test file is an empty placeholder" {
    while IFS= read -r file; do
        grep -q '^@test ' "$file" || { echo "no tests in: $file"; return 1; }
    done < <(test_files)
}

@test "every Gaudi script is exercised by the suite" {
    while IFS= read -r file; do
        name="${file#./}"
        grep -rqF -- "$name" test/unit test/e2e test/support \
            || { echo "no test mentions: $name"; return 1; }
    done < <(source_files)
}

@test "every function in the libraries is called by name in a test" {
    missing=""
    for library in bin/helpers.sh bin/commands.sh bin/installer.sh; do
        while IFS= read -r function_name; do
            grep -rqF -- "$function_name" test/unit test/e2e || missing="$missing $library:$function_name"
        done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_:]*\)() {.*/\1/p' "$library")
    done
    [[ -z "$missing" ]] || { echo "untested functions:$missing"; return 1; }
}

@test "every function of the setup steps is defined in a file that has its own tests" {
    # Step functions run when their file is sourced; each step file must
    # appear in a test (checked above), and must not define functions twice.
    duplicates="$(cat lib/*.sh lib/*/*.sh configs/*.sh bin/*.sh | sed -n 's/^\([A-Za-z_][A-Za-z0-9_:]*\)() {.*/\1/p' | sort | uniq -d)"
    [[ -z "$duplicates" ]] || { echo "defined more than once: $duplicates"; return 1; }
}

@test "setup.sh, the CLI usage and the README list the same setup flags" {
    flags_in_setup="$(sed -n 's/^ *\(--[a-z-]*\)|*.*)$/\1/p; s/^ *\(--[a-z-]*\))$/\1/p' setup.sh | grep -v -- '--help' | sort -u)"
    [[ -n "$flags_in_setup" ]]
    for flag in $flags_in_setup; do
        grep -qF -- "$flag" bin/gaudi || { echo "bin/gaudi usage lacks $flag"; return 1; }
        grep -qF -- "$flag" README.md || { echo "README lacks $flag"; return 1; }
        sed -n '/^Usage: setup.sh/p' setup.sh | grep -qF -- "$flag" || { echo "setup.sh usage lacks $flag"; return 1; }
        grep -rqF -- "$flag" test/unit test/e2e || { echo "no test uses $flag"; return 1; }
    done
}

@test "every GAUDI_* variable the code reads is documented in the README" {
    variables="$(cat install.sh setup.sh backup.sh check.sh bin/gaudi bin/*.sh lib/*.sh lib/*/*.sh configs/*.sh \
        | grep -o 'GAUDI_[A-Z_]*' | sort -u \
        | grep -v -e '^GAUDI_FAILURES$' -e '^GAUDI_SETUP_SHELL$' -e '^GAUDI_SHELL_' -e '^GAUDI_$')"
    [[ -n "$variables" ]]
    missing=""
    for variable in $variables; do
        grep -qF -- "$variable" README.md || missing="$missing $variable"
    done
    [[ -z "$missing" ]] || { echo "undocumented:$missing"; return 1; }
}

@test "every GAUDI_* variable the code reads is used in a test" {
    variables="$(cat install.sh setup.sh backup.sh check.sh bin/gaudi bin/*.sh lib/*.sh lib/*/*.sh configs/*.sh \
        | grep -o 'GAUDI_[A-Z_]*' | sort -u \
        | grep -v -e '^GAUDI_FAILURES$' -e '^GAUDI_SHELL_' -e '^GAUDI_$')"
    missing=""
    for variable in $variables; do
        grep -rqF -- "$variable" test/unit test/e2e test/helper.bash || missing="$missing $variable"
    done
    [[ -z "$missing" ]] || { echo "never set or checked in a test:$missing"; return 1; }
}

@test "the code never reads gaudi-shell's GAUDI_SHELL or GAUDI_SHELL_PROFILE" {
    ! grep -nE 'GAUDI_SHELL([^_A-Z]|$)|GAUDI_SHELL_PROFILE' install.sh setup.sh backup.sh check.sh bin/gaudi bin/*.sh lib/*.sh lib/*/*.sh configs/*.sh \
        | grep -v '^bin/helpers.sh:.*#'
}

@test "installer downloads never use the pattern that hides a failed download" {
    # bash -c "$(curl ...)" runs an empty script, successfully, when curl fails
    ! grep -nE '(bash|sh) -c "\$\(curl' install.sh setup.sh backup.sh check.sh bin/gaudi bin/*.sh lib/*.sh lib/*/*.sh configs/*.sh
}

@test "loops that may prompt never read their list from stdin" {
    # `while read ...; done < <(...)` steals the keyboard from prompts inside
    # the loop. Loops in the steps that prompt must use their own descriptor.
    for file in lib/install-configurations.sh configs/configure-gaudi.sh; do
        ! grep -nE 'done < <\(' "$file"
    done
    grep -q 'done 3< <(gaudi::brewfiles)' lib/install-software.sh
    grep -q 'done 4< <(find' bin/helpers.sh
}

@test "the README's example commands use flags that exist" {
    while IFS= read -r flag; do
        grep -qF -- "$flag" setup.sh || { echo "README mentions unknown flag $flag"; return 1; }
    done < <(grep -o -- '--skip-[a-z-]*' README.md | sort -u)
}

# --- continuous integration ------------------------------------------------------------

WORKFLOW=".github/workflows/tests.yml"

@test "CI runs on pull requests, in the merge queue and on pushes to master" {
    grep -q '^  pull_request:' "$WORKFLOW"
    grep -q '^  merge_group:' "$WORKFLOW"
    grep -q 'branches: \[master\]' "$WORKFLOW"
}

@test "CI runs every suite, under every bash, plus both real end-to-end runs" {
    grep -q 'run: test/run --every-bash' "$WORKFLOW"
    grep -q 'run: test/run real' "$WORKFLOW"
    grep -q 'GAUDI_E2E_REAL_MACOS=1 test/real/macos.sh' "$WORKFLOW"
    grep -q 'os: \[macos-latest, ubuntu-latest\]' "$WORKFLOW"
}

@test "the 'tests passed' gate waits for every other job and cannot be skipped" {
    jobs="$(sed -n '/^jobs:/,$p' "$WORKFLOW" | sed -n 's/^  \([a-z-]*\):$/\1/p' | grep -v '^passed$' | sort | tr '\n' ' ')"
    needs="$(sed -n 's/^    needs: \[\(.*\)\]$/\1/p' "$WORKFLOW" | tr ',' '\n' | tr -d ' ' | sort | tr '\n' ' ')"
    [[ -n "$jobs" ]]
    [[ "$jobs" == "$needs" ]] || { echo "jobs: $jobs / gate needs: $needs"; return 1; }
    grep -q 'name: tests passed' "$WORKFLOW"
    sed -n '/^  passed:/,$p' "$WORKFLOW" | grep -q 'if: always()'
}

@test "CI only gets read access to the repository" {
    grep -A1 '^permissions:' "$WORKFLOW" | grep -q 'contents: read'
}

@test "the README describes the CI gate and links the workflow" {
    grep -qF 'actions/workflows/tests.yml/badge.svg' README.md
    grep -qF 'tests passed' README.md
}

@test "the sandbox detaches tests from the terminal, so no test waits for the keyboard" {
    grep -q '^    exec </dev/null$' test/helper.bash
    grep -q '</dev/null$' test/support/run-file
}
