#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_FAILURES=()

# Print the path of a command: PATH first, then the Homebrew bin directories,
# which are not on PATH yet right after Homebrew is installed.
# GAUDI_BREW_BIN_DIRS (colon-separated) overrides those directories.
gaudi::find_command() {
    local command_name="$1"
    local dirs="${GAUDI_BREW_BIN_DIRS-/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.linuxbrew/bin}"
    local candidate=""
    local dir=""
    local old_ifs="$IFS"

    candidate="$(type -P "$command_name" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        printf "%s" "$candidate"
        return 0
    fi

    IFS=":"
    for dir in $dirs; do
        if [[ -n "$dir" && -x "$dir/$command_name" ]]; then
            IFS="$old_ifs"
            printf "%s" "$dir/$command_name"
            return 0
        fi
    done
    IFS="$old_ifs"

    return 1
}

gaudi::command_exists() {
    gaudi::find_command "$1" >/dev/null
}

gaudi::is_root() {
    [[ "$(id -u 2>/dev/null || printf 1)" == "0" ]]
}

# True when a person can answer prompts
gaudi::interactive() {
    [[ -t 0 ]]
}

gaudi::log() {
    printf "%b\n" "${BLUE:-}[INFO]${NC:-} $*"
}

gaudi::success() {
    printf "%b\n" "${GREEN:-}[OK]${NC:-} $*"
}

gaudi::warn() {
    printf "%b\n" "${YELLOW:-}[WARN]${NC:-} $*" >&2
}

gaudi::error() {
    printf "%b\n" "${RED:-}[ERROR]${NC:-} $*" >&2
}

# A failed package, hook or config is recorded and reported at the end
# instead of aborting the whole setup.
gaudi::record_failure() {
    GAUDI_FAILURES+=("$*")
    gaudi::error "Failed: $*"
}

gaudi::report_failures() {
    local failure=""

    [[ ${#GAUDI_FAILURES[@]} -gt 0 ]] || return 0

    gaudi::error "${#GAUDI_FAILURES[@]} step(s) failed:"
    for failure in "${GAUDI_FAILURES[@]}"; do
        printf "  - %s\n" "$failure" >&2
    done
    return 1
}

# Sets and exports OS: osx, debian, fedora, arch, opensuse, or a name Gaudi
# does not automate (centos, linux, unknown).
gaudi::detect_os() {
    local kernel=""

    kernel="$(uname -s 2>/dev/null || printf unknown)"
    case "$kernel" in
        Darwin)
            OS="osx"
            ;;
        Linux)
            if gaudi::command_exists apt-get; then
                OS="debian"
            elif gaudi::command_exists dnf; then
                OS="fedora"
            elif gaudi::command_exists pacman; then
                OS="arch"
            elif gaudi::command_exists zypper; then
                OS="opensuse"
            elif gaudi::command_exists yum; then
                OS="centos"
            else
                OS="linux"
            fi
            ;;
        *)
            OS="unknown"
            ;;
    esac

    export OS
}

# Sets GAUDI_SETUP_SHELL and GAUDI_SETUP_PROFILE.
# These names deliberately avoid the GAUDI_SHELL_* namespace, which belongs to
# gaudi-shell and is exported in every session where it is loaded.
gaudi::detect_shell() {
    local shell_name="${GAUDI_TARGET_SHELL:-}"
    local profile="${GAUDI_SETUP_PROFILE:-}"

    if [[ -z "$shell_name" && -n "${SHELL:-}" ]]; then
        shell_name="${SHELL##*/}"
    fi

    if [[ -z "$shell_name" ]]; then
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            shell_name="zsh"
        elif [[ -n "${BASH_VERSION:-}" ]]; then
            shell_name="bash"
        else
            shell_name="sh"
        fi
    fi

    GAUDI_SETUP_SHELL="$shell_name"

    if [[ -z "$profile" ]]; then
        case "$shell_name" in
            bash)
                if [[ "${OS:-}" == "osx" ]]; then
                    profile="$HOME/.bash_profile"
                else
                    profile="$HOME/.bashrc"
                fi
                ;;
            zsh)
                profile="$HOME/.zshrc"
                ;;
            fish)
                profile="$HOME/.config/fish/config.fish"
                ;;
            *)
                profile="$HOME/.profile"
                ;;
        esac
    fi

    # Never write a profile relative to the current directory
    [[ "$profile" == /* ]] || profile="$HOME/$profile"
    GAUDI_SETUP_PROFILE="$profile"

    export GAUDI_SETUP_SHELL GAUDI_SETUP_PROFILE
}

# Read a one-key answer. Prints "y" without asking under GAUDI_ASSUME_YES (the
# default, or the first allowed character, when "y" is not an allowed answer),
# and the default (or "n") when nobody is at the keyboard.
#   gaudi::read_answer [allowed characters] [default]
gaudi::read_answer() {
    local options="${1:-yYnN}"
    local default="${2:-}"
    local input=""

    if [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]]; then
        if [[ "y" =~ ^[$options]$ ]]; then
            printf "y"
        else
            printf "%s" "${default:-${options:0:1}}"
        fi
        return 0
    fi

    if ! gaudi::interactive; then
        printf "%s" "${default:-n}"
        return 0
    fi

    while [[ -z "$input" ]]; do
        if ! IFS= read -r -n 1 input; then
            # EOF: fall back instead of looping forever
            printf "%s" "${default:-n}"
            return 0
        fi
        if [[ -z "$input" && -n "$default" ]]; then
            input="$default"
        fi
        if ! [[ "$input" =~ ^[$options]$ ]]; then
            gaudi::error "Please enter a valid answer [$options]"
            input=""
        fi
    done

    printf "\n" >&2
    printf "%s" "$input"
}

gaudi::confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local suffix="[y/N]"
    local answer=""

    [[ "$default" =~ ^[Yy]$ ]] && suffix="[Y/n]"
    printf "%b " "$prompt $suffix"
    answer="$(gaudi::read_answer "yYnN" "$default")"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Returns 1 when stdin is exhausted before a valid address is entered.
gaudi::read_email() {
    local input=""
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

    while [[ -z "$input" ]]; do
        IFS= read -r input || return 1
        if ! [[ "$input" =~ $email_regex ]]; then
            gaudi::error "Please enter a valid email address"
            input=""
        fi
    done

    printf "%s" "$input"
}

# Read a Git URL that can be reached; an empty answer takes the default.
# Under GAUDI_ASSUME_YES nothing is read: the default is the answer.
# Returns 1 when stdin is exhausted (or the default was taken without asking)
# and the URL is still unreachable.
gaudi::read_git_url() {
    local input=""
    local default="${1:-https://github.com/g-udi/gaudi-templates.git}"
    local eof="false"

    [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]] && eof="true"

    while true; do
        [[ "$eof" == "true" ]] || IFS= read -e -r input || eof="true"
        input="${input:-$default}"
        if GIT_TERMINAL_PROMPT=0 git ls-remote "$input" >/dev/null 2>&1; then
            break
        fi
        gaudi::error "Unable to access repository: $input"
        [[ "$eof" == "true" ]] && return 1
        printf "%b" "${YELLOW:-}Enter a reachable Git URL:${NC:-} " >&2
        input=""
    done

    printf "%s" "$input"
}

gaudi::append_once() {
    local file="$1"
    local line="$2"
    local dir=""

    dir="$(dirname "$file")"
    mkdir -p "$dir"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || printf "\n%s\n" "$line" >> "$file"
}

gaudi::user_bin_dir() {
    printf "%s" "${GAUDI_BIN_DIR:-$HOME/.local/bin}"
}

gaudi::shell_path_line() {
    local bin_dir="$1"

    if [[ "${GAUDI_SETUP_SHELL:-}" == "fish" ]]; then
        printf "contains -- \"%s\" \$PATH; or set -gx PATH \"%s\" \$PATH" "$bin_dir" "$bin_dir"
    else
        printf "export PATH=\"%s:\$PATH\"" "$bin_dir"
    fi
}

# Load Homebrew into this shell and make sure new shells get it too.
gaudi::activate_brew() {
    local brew_bin=""
    local line=""

    # Homebrew is not on PATH yet right after it is installed
    brew_bin="$(gaudi::find_command brew)" || return 1
    eval "$("$brew_bin" shellenv)"

    if [[ "${GAUDI_SETUP_SHELL:-}" == "fish" ]]; then
        line="$brew_bin shellenv fish | source"
    else
        line="eval \"\$($brew_bin shellenv)\""
    fi

    gaudi::append_once "$GAUDI_SETUP_PROFILE" "$line"
}

gaudi::install_cli() {
    local bin_dir=""
    local target=""
    local path_line=""

    bin_dir="$(gaudi::user_bin_dir)"
    target="$bin_dir/gaudi"
    mkdir -p "$bin_dir"
    ln -sf "$SOURCE_LOCATION/bin/gaudi" "$target"
    chmod +x "$SOURCE_LOCATION/bin/gaudi"

    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        path_line="$(gaudi::shell_path_line "$bin_dir")"
        gaudi::append_once "$GAUDI_SETUP_PROFILE" "$path_line"
        gaudi::warn "$bin_dir was added to $GAUDI_SETUP_PROFILE. Restart your shell or source that file before using gaudi directly."
    fi

    gaudi::success "Installed gaudi CLI at $target"
}

gaudi::metadata_value() {
    local file="$1"
    local key="$2"
    local value=""

    value="$(sed -n "s/^# ${key}: *//p" "$file" | head -n 1)"
    printf "%s" "$value"
}

# The one rule for a dotfile path (a dotfiles.list entry, or a file under the
# templates' dotfiles directory): it must name something strictly inside the
# home directory. Prints the path relative to the home directory, tidied up
# ("./.zshrc" and ".config/" become ".zshrc" and ".config"), or fails for an
# empty path, the home directory itself (".", "./"), an absolute or "~" path,
# anything with "..", and a path that leaves the home directory through a
# symlinked directory.
gaudi::dotfile_path() {
    local entry="$1"
    local previous=""
    local home=""
    local parent=""

    entry="${entry#"${entry%%[![:space:]]*}"}"
    entry="${entry%"${entry##*[![:space:]]}"}"
    while [[ "$entry" != "$previous" ]]; do
        previous="$entry"
        entry="${entry//\/\///}"
        entry="${entry//\/.\///}"
        entry="${entry#./}"
        entry="${entry%/}"
        entry="${entry%/.}"
    done
    case "$entry" in
        ""|"."|/*|"~"*|*".."*)
            return 1
            ;;
    esac

    # Compare real directories: the deepest one that exists above the path
    # has to be the home directory or inside it
    if home="$(cd -P -- "$HOME" 2>/dev/null && pwd)"; then
        parent="$HOME/$entry"
        parent="${parent%/*}"
        while [[ -n "$parent" && ! -d "$parent" ]]; do
            parent="${parent%/*}"
        done
        parent="$(cd -P -- "${parent:-/}" 2>/dev/null && pwd)" || return 1
        [[ "$parent" == "$home" || "$parent" == "$home"/* ]] || return 1
    fi

    printf "%s" "$entry"
}

gaudi::source_if_exists() {
    local file="$1"

    if [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
    else
        gaudi::warn "Skipping missing step: $file"
    fi
}

# Run the Homebrew installer. Under GAUDI_ASSUME_YES it is told not to wait
# for RETURN (NONINTERACTIVE=1), which it otherwise does on a terminal.
# install.sh has its own copy of this: it runs before Gaudi is cloned.
gaudi::install_homebrew() {
    (
        [[ "${GAUDI_ASSUME_YES:-false}" != "true" ]] || export NONINTERACTIVE=1
        gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    )
}

# Homebrew on Linux is optional: it is what installs Brewfiles there.
# Homebrew refuses to run as root, so root only gets the distribution packages.
gaudi::offer_linuxbrew() {
    if gaudi::command_exists brew; then
        :
    elif gaudi::is_root; then
        gaudi::warn "Homebrew cannot be installed as root: run Gaudi as a regular user to install Brewfiles"
    elif gaudi::confirm "Install Homebrew on Linux? It is required for Brewfiles." "n"; then
        gaudi::install_homebrew || gaudi::record_failure "Homebrew installation"
    fi

    if gaudi::command_exists brew; then
        gaudi::activate_brew || gaudi::warn "Homebrew could not be loaded into this shell"
    fi
}

# Download an installer script and run it with the given interpreter.
#   gaudi::run_remote_script <interpreter> <url> [script args...]
# Unlike handing the output of curl straight to `bash -c`, a failed or empty download is an error
# instead of silently running nothing.
gaudi::run_remote_script() {
    local interpreter="$1"
    local url="$2"
    local script=""
    shift 2

    if ! script="$(curl -fsSL "$url")" || [[ -z "$script" ]]; then
        gaudi::error "Could not download $url"
        return 1
    fi

    "$interpreter" -c "$script" "$@"
}

# What stopped the last gaudi::source_guarded or gaudi::call_guarded from
# succeeding ("line 4 failed with status 1"); empty when it succeeded.
gaudi_guarded_failure=""
# The guarded run in progress: its file, its first failing command, and
# whether it called exit
gaudi_guarded_file=""
gaudi_guarded_error=""
gaudi_guarded_exited=""
# What `exit` means inside a guarded file: stop the file, never the run
gaudi_guarded_exit='gaudi_guarded_exited=true; return'

# ERR trap of a guarded run: remember the first unhandled failing command
# written in the guarded file itself (not in the scripts or functions it uses).
#   gaudi::guarded_error <status> <source file> <line> <function>
gaudi::guarded_error() {
    [[ "$2" == "$gaudi_guarded_file" && -z "$gaudi_guarded_error" ]] || return 0
    if [[ "${4:-source}" != "source" && "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        # bash 3.2 counts lines from the start of the function
        gaudi_guarded_error="a command in $4() failed with status $1"
    else
        gaudi_guarded_error="line $3 failed with status $1"
    fi
    return 0
}

# EXIT trap of a guarded run. Only reached when a template file ends the whole
# run in a way that cannot be turned into a return (an unset variable under
# `set -u`, its own `set -e`, `builtin exit`): the run still ends, but with
# its summary.
gaudi::guarded_abort() {
    local status="$1"

    trap - EXIT
    gaudi::record_failure "$gaudi_guarded_file ended the run early (status $status)"
    gaudi::report_failures || true
    exit 1
}

# Run a template file (a hook, a config, a list) in this shell, so it can use
# Gaudi's functions and what it exports reaches the steps after it, without
# letting it end the run or hide a failure:
#   - a command that fails without the file handling it (the cases `set -e`
#     would stop at) is a failure, and the file still runs to its end
#     (bash 3.2 does not see a failing `( ... )` unless it is the last command);
#   - `exit` stops the file like `return` does and is a failure;
#   - so is a non-zero status of its last command or of its `return`.
# With a function name, that function (defined by the file) is called instead
# of sourcing the file.
#
# Always returns 0 and leaves the reason in gaudi_guarded_failure (empty on
# success). It must be called as a plain statement: bash does not run the ERR
# trap for anything called from a condition, `!`, `&&` or `||`.
#   gaudi::guarded <file> [function]
gaudi::guarded() {
    local _gaudi_guarded_status=0
    local _gaudi_guarded_flags="$-"
    local _gaudi_guarded_aliases="false"
    local _gaudi_guarded_traps=""
    # A guarded file may start another guarded run: keep its state
    local _gaudi_guarded_outer_file="$gaudi_guarded_file"
    local _gaudi_guarded_outer_error="$gaudi_guarded_error"
    local _gaudi_guarded_outer_exited="$gaudi_guarded_exited"

    shopt -q expand_aliases && _gaudi_guarded_aliases="true"
    _gaudi_guarded_traps="$(trap -p ERR EXIT)"
    gaudi_guarded_file="$1"
    gaudi_guarded_error=""
    gaudi_guarded_exited=""

    # Aliases are expanded when a command is read, so this reaches every
    # `exit` written in the file, including the ones inside its functions.
    shopt -s expand_aliases
    alias exit='eval "$gaudi_guarded_exit"'
    # `source file || handle` is not enough to survive a failing command:
    # bash 3.2 (the bash macOS ships) still exits under `set -e`.
    set +e
    set -E
    trap 'gaudi::guarded_error "$?" "${BASH_SOURCE[0]}" "$LINENO" "${FUNCNAME[0]:-}"' ERR
    trap 'gaudi::guarded_abort "$?"' EXIT

    if [[ -n "${2:-}" ]]; then
        "$2"
    else
        # shellcheck source=/dev/null
        source "$1"
    fi
    _gaudi_guarded_status=$?

    trap - ERR EXIT
    eval "$_gaudi_guarded_traps"
    [[ "$_gaudi_guarded_flags" == *E* ]] || set +E
    [[ -n "$_gaudi_guarded_outer_file" ]] || unalias exit
    [[ "$_gaudi_guarded_aliases" == "true" ]] || shopt -u expand_aliases

    gaudi_guarded_failure="$gaudi_guarded_error"
    if [[ "$gaudi_guarded_exited" == "true" ]]; then
        gaudi_guarded_failure="it called exit: use return to stop early"
    elif [[ -z "$gaudi_guarded_failure" && "$_gaudi_guarded_status" -ne 0 ]]; then
        gaudi_guarded_failure="it ended with status $_gaudi_guarded_status"
    fi
    gaudi_guarded_file="$_gaudi_guarded_outer_file"
    gaudi_guarded_error="$_gaudi_guarded_outer_error"
    gaudi_guarded_exited="$_gaudi_guarded_outer_exited"

    [[ "$_gaudi_guarded_flags" != *e* ]] || set -e
    return 0
}

# Source a template file; see gaudi::guarded.
gaudi::source_guarded() {
    gaudi::guarded "$1"
}

# Call a function a template file defined; see gaudi::guarded.
#   gaudi::call_guarded <file> <function>
gaudi::call_guarded() {
    gaudi::guarded "$1" "$2"
}

# Run one template hook. A failing hook is recorded, not fatal.
gaudi::run_hook() {
    local hook="$1"

    # Hooks run real commands, so a dry run must only name them
    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        printf "DRY RUN: hook %s\n" "$hook"
        return 0
    fi
    gaudi::log "Running hook: $hook"
    gaudi::source_guarded "$hook"
    [[ -z "$gaudi_guarded_failure" ]] || gaudi::record_failure "hook $hook: $gaudi_guarded_failure"
}

# Run every template hook whose file name matches the given pattern.
gaudi::run_hooks_matching() {
    local hook=""

    while IFS= read -r -u 4 hook; do
        [[ -n "$hook" ]] || continue
        gaudi::run_hook "$hook"
    done 4< <(gaudi::hook_files "$1")
}

# Run the hooks of one Brewfile: <phase>.bundle-<name>.hooks.sh, then
# <phase>.bundle-<name>.<topic>.hooks.sh for several hooks per Brewfile. A
# file that belongs to a Brewfile with a longer name (dev.tools, when this
# one is dev) is left to that Brewfile.
#   gaudi::run_bundle_hooks <pre|post> <Brewfile name>
gaudi::run_bundle_hooks() {
    local phase="$1"
    local name="$2"
    local hook=""
    local owner=""

    while IFS= read -r -u 4 hook; do
        [[ -n "$hook" ]] || continue
        owner="$(gaudi::bundle_hook_owner "$hook")"
        [[ -z "$owner" || "$owner" == "$name" ]] || continue
        gaudi::run_hook "$hook"
    done 4< <(gaudi::hook_files "$phase.bundle-$name.hooks.sh"; gaudi::hook_files "$phase.bundle-$name.*.hooks.sh")
}

# --- Names from before the gaudi:: prefix ---------------------------------------
# Hooks and configuration scripts in existing templates call these.

command_exists() {
    gaudi::command_exists "$@"
}

get_os() {
    gaudi::detect_os "$@"
}

get_shell_type() {
    gaudi::detect_shell "$@"
}

read_answer() {
    gaudi::read_answer "$@"
}

read_email() {
    gaudi::read_email "$@"
}

read_git_url() {
    gaudi::read_git_url "$@"
}
