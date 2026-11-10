#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154  # status/output come from bats' `run`
#
# Shared test helper. Every test runs against a sandbox:
#
#   $HOME      throwaway home directory
#   $MACHINE   the simulated machine: what the fake package managers installed
#              and a log of every external command that was called
#   $PATH      only the fake tools (test/fakes) and a whitelist of real
#              coreutils, so no test can reach the real brew, apt, sudo or curl
#
# Nothing outside $BATS_TEST_TMPDIR is read or written.

GAUDI_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

# Real tools the code under test is allowed to use
_BASE_TOOLS="env cat sed grep find sort head tail tr wc mkdir rm rmdir cp mv ln ls touch chmod dirname basename readlink mktemp git awk tee cut uniq diff date sleep xargs tput comm cmp expr true false pwd sh tar"

_COMMON_FAKES="uname sudo id curl ssh-keygen ssh-add ssh-agent gem ruby npm"
_DARWIN_FAKES="xcode-select defaults mas"
_DEBIAN_FAKES="apt-get apt-mark"
_FEDORA_FAKES="dnf"

# gaudi_sandbox [darwin|debian|fedora]
# darwin: Homebrew installed and on PATH, Command Line Tools installed.
# debian: apt available, no Homebrew.
gaudi_sandbox() {
    local os="${1:-darwin}"
    local name=""
    local real=""

    for name in $(compgen -v | grep -E '^(GAUDI|FAKE_|HOMEBREW_|NVM_|SSH_AUTH_SOCK|OS$)' || true); do
        [[ "$name" == "GAUDI_TEST_BASH" ]] && continue
        unset "$name"
    done

    GAUDI_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    # Physical path: on macOS the temp directory sits behind a /var symlink
    SANDBOX="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    FAKEBIN="$SANDBOX/fakebin"
    BASEBIN="$SANDBOX/basebin"
    WORK="$SANDBOX/cwd"
    export GAUDI_ROOT
    export HOME="$SANDBOX/home"
    export MACHINE="$SANDBOX/machine"
    export FAKES_DIR="$GAUDI_ROOT/test/fakes"
    export FAKE_BREW_PREFIX="$MACHINE/homebrew"
    # A test may call gaudi_sandbox again to switch machine type: resolve real
    # tools against the original PATH and start from an empty machine.
    _REAL_PATH="${_REAL_PATH:-$PATH}"
    PATH="$_REAL_PATH"
    _PYTHON3="$(type -P python3 || true)"
    _build_tool_cache
    rm -rf "$FAKEBIN" "$BASEBIN" "$MACHINE"
    mkdir -p "$HOME" "$MACHINE" "$WORK"
    cp -R "$_TOOL_CACHE/basebin" "$BASEBIN"
    cp -R "$_TOOL_CACHE/fakebin-$os" "$FAKEBIN"

    export PATH="$FAKEBIN:$BASEBIN"
    # Where Gaudi looks for a Homebrew that is not on PATH yet
    export GAUDI_BREW_BIN_DIRS="$FAKE_BREW_PREFIX/bin"

    case "$os" in
        darwin)
            export FAKE_UNAME="Darwin"
            : > "$MACHINE/clt"
            ;;
        debian|fedora)
            export FAKE_UNAME="Linux"
            ;;
    esac

    # A machine with gaudi-shell loaded exports these; Gaudi must ignore them
    export GAUDI_SHELL="/somewhere/gaudi-shell"
    export GAUDI_SHELL_PROFILE=".zshrc"

    export SHELL="/bin/zsh"
    export TERM="dumb"
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME="Gaudi Test" GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Gaudi Test" GIT_COMMITTER_EMAIL="test@example.com"

    # Tests must behave the same when the suite is started from a terminal:
    # without this, code that asks "is someone at the keyboard?" would say yes
    # and wait for the person running the tests. A test that wants to answer a
    # prompt pipes the answer in and calls `interactive`.
    exec </dev/null

    cd "$WORK" || return 1
}

# use_machine <name>: switch to another simulated machine of the same OS. It
# has its own home directory and its own installed software; the tools on
# PATH stay the same. Used to back up one machine and restore onto another.
use_machine() {
    export HOME="$SANDBOX/machines/$1/home"
    export MACHINE="$SANDBOX/machines/$1/state"
    export FAKE_BREW_PREFIX="$MACHINE/homebrew"
    export GAUDI_BREW_BIN_DIRS="$FAKE_BREW_PREFIX/bin"
    mkdir -p "$HOME" "$MACHINE"
    [[ "${FAKE_UNAME:-}" == "Darwin" ]] && : > "$MACHINE/clt"
    return 0
}

# The tool directories are the same for every test, so they are built once per
# bats run and copied (as symlinks) into each sandbox.
_build_tool_cache() {
    local name=""
    local real=""
    local fakebin_save="${FAKEBIN:-}"

    _TOOL_CACHE="${BATS_RUN_TMPDIR:-${BATS_TMPDIR:-/tmp}}/gaudi-tool-cache-$(basename "${GAUDI_TEST_BASH:-default}")"
    [[ -d "$_TOOL_CACHE/fakebin-debian" ]] && return 0

    mkdir -p "$_TOOL_CACHE/basebin" "$_TOOL_CACHE/fakebin-darwin" "$_TOOL_CACHE/fakebin-fedora" "$_TOOL_CACHE/fakebin-debian.tmp"
    for name in $_BASE_TOOLS; do
        real="$(type -P "$name" || true)"
        [[ -n "$real" ]] && ln -sf "$real" "$_TOOL_CACHE/basebin/$name"
    done
    # The bash that runs the code under test (test/run --bash picks another)
    ln -sf "${GAUDI_TEST_BASH:-$(type -P bash)}" "$_TOOL_CACHE/basebin/bash"

    FAKEBIN="$_TOOL_CACHE/fakebin-darwin"
    # shellcheck disable=SC2086
    add_tool $_COMMON_FAKES $_DARWIN_FAKES brew
    FAKEBIN="$_TOOL_CACHE/fakebin-fedora"
    # shellcheck disable=SC2086
    add_tool $_COMMON_FAKES $_FEDORA_FAKES
    FAKEBIN="$_TOOL_CACHE/fakebin-debian.tmp"
    # shellcheck disable=SC2086
    add_tool $_COMMON_FAKES $_DEBIAN_FAKES
    FAKEBIN="$fakebin_save"
    # Renamed last, so a half-built cache is never taken for a complete one
    mv "$_TOOL_CACHE/fakebin-debian.tmp" "$_TOOL_CACHE/fakebin-debian"
}

# Put fake tools on the machine's PATH
add_tool() {
    local name=""

    for name in "$@"; do
        if [[ "$name" == "brew" ]]; then
            cp "$FAKES_DIR/brew" "$FAKEBIN/brew"
            chmod +x "$FAKEBIN/brew"
        else
            ln -sf "$FAKES_DIR/tool" "$FAKEBIN/$name"
        fi
    done
}

# Take tools away from the machine (fake or real)
remove_tool() {
    local name=""

    for name in "$@"; do
        rm -f "$FAKEBIN/$name" "$BASEBIN/$name"
    done
}

# --- running the code under test ----------------------------------------------

# call <function> [args...]: one library function, loaded like setup.sh does
call() {
    bash "$GAUDI_ROOT/test/support/call" "$@"
}

# step <file>...: setup step(s) sourced like setup.sh does
step() {
    bash "$GAUDI_ROOT/test/support/step" "$@"
}

# on_terminal "<answers>" <command> [args...]: run a command on a real
# pseudo-terminal, typing one character of <answers> at each prompt.
on_terminal() {
    "$_PYTHON3" "$GAUDI_ROOT/test/support/pty" "$@"
}

# Skip a test that needs a pseudo-terminal when python3 is not available
require_terminal() {
    [[ -n "${_PYTHON3:-}" ]] || skip "python3 is needed to open a pseudo-terminal"
}

# Pretend a person is at the keyboard for the rest of this test
interactive() {
    export GAUDI_TEST_INTERACTIVE=1
}

# --- fixtures -------------------------------------------------------------------

# write_file <path>: write stdin to a file, creating its directory
write_file() {
    mkdir -p "$(dirname "$1")"
    cat > "$1"
}

# Turn a directory into a git repository on branch master with one commit
init_git_repo() {
    git -C "$1" init -q
    git -C "$1" checkout -q -b master 2>/dev/null || true
    git -C "$1" add -A
    git -C "$1" commit -q -m "fixture" --allow-empty
}

# A git repository holding the Gaudi checkout under test, as install.sh would
# clone it from GitHub. Prints its path.
gaudi_remote() {
    local remote="$SANDBOX/remotes/gaudi"

    if [[ ! -d "$remote/.git" ]]; then
        mkdir -p "$remote"
        cp -R "$GAUDI_ROOT/bin" "$GAUDI_ROOT/lib" "$GAUDI_ROOT/configs" "$remote/"
        cp "$GAUDI_ROOT/setup.sh" "$GAUDI_ROOT/backup.sh" "$GAUDI_ROOT/install.sh" "$GAUDI_ROOT/.gitignore" "$remote/"
        init_git_repo "$remote" >/dev/null
    fi
    printf "%s" "$remote"
}

# A plain copy of the checkout whose step scripts a test may replace
gaudi_copy() {
    local copy="$SANDBOX/gaudi-copy"

    if [[ ! -d "$copy" ]]; then
        mkdir -p "$copy"
        cp -R "$GAUDI_ROOT/bin" "$GAUDI_ROOT/lib" "$GAUDI_ROOT/configs" "$copy/"
        cp "$GAUDI_ROOT/setup.sh" "$GAUDI_ROOT/backup.sh" "$GAUDI_ROOT/install.sh" "$copy/"
    fi
    printf "%s" "$copy"
}

# A realistic templates directory: Brewfiles, apt and gem lists, hooks, configs.
# Hooks and configs leave marks under $MACHINE so tests can see they ran.
standard_templates() {
    local dir="$1"

    write_file "$dir/lists/core.Brewfile" <<'EOF'
# @Name: Core tools
# @Description: Command-line tools
tap "example/tap"
# Lightweight JSON processor
brew "jq"
brew "example/tap/special"
EOF
    write_file "$dir/lists/apps.Brewfile" <<'EOF'
# @Name: Applications
cask_args appdir: "/Applications"
cask "raycast"
cask "kitty"
EOF
    write_file "$dir/lists/extras.Brewfile" <<'EOF'
# @Name: Extras
mas "Amphetamine", id: 937984704
npm "eslint"
uv "pylint"
go "golang.org/x/tools/gopls"
cargo "ripgrep"
vscode "esbenp.prettier-vscode"
EOF
    write_file "$dir/lists/default.apt.list.sh" <<'EOF'
# @Name: Apt Default
# @Description: Debian packages
# @List: aptList
aptList=(
  "tree::Directory listing"
  "htop"
)
EOF
    write_file "$dir/lists/default.gem.list.sh" <<'EOF'
# @Name: Gems
# @List: gemList
gemList=(
  "tmuxinator::Manage tmux sessions"
)
EOF
    write_file "$dir/hooks/pre.bundle.hooks.sh" <<'EOF'
printf 'pre.bundle\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/post.bundle.hooks.sh" <<'EOF'
printf 'post.bundle\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/bundle/pre.bundle-core.hooks.sh" <<'EOF'
printf 'pre.bundle-core\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/bundle/post.bundle-core.hooks.sh" <<'EOF'
printf 'post.bundle-core\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/bundle/post.bundle-core.extra.hooks.sh" <<'EOF'
printf 'post.bundle-core.extra\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/pre.apt.hooks.sh" <<'EOF'
printf 'pre.apt\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/hooks/post.gem.hooks.sh" <<'EOF'
printf 'post.gem\n' >> "$MACHINE/hooks.log"
EOF
    write_file "$dir/configs/finder_pathbar.configs.osx.sh" <<'EOF'
_info="Show Finder path bar"
_command() {
    defaults write com.apple.finder ShowPathbar -bool true
}
EOF
    write_file "$dir/configs/editor.configs.sh" <<'EOF'
_info="Shared editor config"
_command() {
    printf 'shared-config\n' >> "$MACHINE/configs.log"
}
EOF
    write_file "$dir/configs/swappiness.configs.debian.sh" <<'EOF'
_info="Debian only config"
_command() {
    printf 'debian-config\n' >> "$MACHINE/configs.log"
}
EOF
}

# --- inspecting the simulated machine --------------------------------------------

# Every external command the code under test ran
calls() {
    [[ -f "$MACHINE/calls.log" ]] && cat "$MACHINE/calls.log"
    return 0
}

# Everything installed on a machine, in a stable order, for comparing machines
machine_snapshot() {
    local machine="${1:-$MACHINE}"
    local file=""

    for file in "$machine"/brew/*.txt "$machine/apt.txt" "$machine/dnf.txt" "$machine/gem.txt"; do
        [[ -f "$file" ]] || continue
        printf '[%s]\n' "${file#"$machine"/}"
        sort "$file"
    done
}

# --- assertions -------------------------------------------------------------------

_fail() {
    {
        printf '%s\n' "$1"
        printf -- '--- status: %s\n--- output:\n%s\n' "${status:-}" "${output:-}"
        if [[ -f "$MACHINE/calls.log" ]]; then
            printf -- '--- calls:\n'
            cat "$MACHINE/calls.log"
        fi
    } >&2
    return 1
}

assert_success() {
    [[ "$status" -eq 0 ]] || _fail "expected success, got exit status $status"
}

# assert_failure [status]
assert_failure() {
    if [[ $# -gt 0 ]]; then
        [[ "$status" -eq "$1" ]] || _fail "expected exit status $1, got $status"
    else
        [[ "$status" -ne 0 ]] || _fail "expected a failure, got success"
    fi
}

assert_output_contains() {
    [[ "$output" == *"$1"* ]] || _fail "expected output to contain: $1"
}

refute_output_contains() {
    [[ "$output" != *"$1"* ]] || _fail "expected output NOT to contain: $1"
}

assert_output_equals() {
    [[ "$output" == "$1" ]] || _fail "expected output to equal: $1"
}

assert_equal() {
    [[ "$1" == "$2" ]] || _fail "expected: $2
actual:   $1"
}

assert_file_exists() {
    [[ -e "$1" ]] || _fail "expected to exist: $1"
}

refute_file_exists() {
    [[ ! -e "$1" ]] || _fail "expected NOT to exist: $1"
}

assert_file_contains() {
    [[ -f "$1" ]] || _fail "expected a file: $1"
    grep -Fq -- "$2" "$1" || _fail "expected $1 to contain: $2
$(cat "$1")"
}

refute_file_contains() {
    [[ ! -f "$1" ]] || ! grep -Fq -- "$2" "$1" || _fail "expected $1 NOT to contain: $2"
}

# How many lines of a file contain a string
count_in_file() {
    [[ -f "$1" ]] || { printf '0'; return 0; }
    grep -Fc -- "$2" "$1" || true
}

assert_called() {
    grep -Fq -- "$1" "$MACHINE/calls.log" 2>/dev/null || _fail "expected a call containing: $1"
}

refute_called() {
    ! grep -Fq -- "$1" "$MACHINE/calls.log" 2>/dev/null || _fail "expected NO call containing: $1"
}

# The current directory must stay untouched (nothing written relative to cwd)
assert_cwd_clean() {
    [[ -z "$(ls -A "$WORK")" ]] || _fail "the current directory was written to: $(ls -A "$WORK")"
}
