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

command_exists() {
    gaudi::command_exists "$@"
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

get_os() {
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

gaudi::supported_os() {
    case "${OS:-}" in
        osx|debian|fedora|arch|opensuse)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Sets GAUDI_SETUP_SHELL and GAUDI_SETUP_PROFILE.
# These names deliberately avoid the GAUDI_SHELL_* namespace, which belongs to
# gaudi-shell and is exported in every session where it is loaded.
get_shell_type() {
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

read_answer() {
    local options="${1:-yYnN}"
    local default="${2:-}"
    local input=""

    if [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]]; then
        printf "y"
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
    answer="$(read_answer "yYnN" "$default")"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Returns 1 when stdin is exhausted before a valid address is entered.
read_email() {
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

# Returns 1 when stdin is exhausted and the URL is still unreachable.
read_git_url() {
    local input=""
    local default="${1:-https://github.com/g-udi/gaudi-templates.git}"
    local eof="false"

    while true; do
        IFS= read -e -r input || eof="true"
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

# Locate the brew binary even when it is not on PATH yet (fresh install).
gaudi::brew_bin() {
    gaudi::find_command brew
}

# Load Homebrew into this shell and make sure new shells get it too.
gaudi::activate_brew() {
    local brew_bin=""
    local line=""

    brew_bin="$(gaudi::brew_bin)" || return 1
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

gaudi::source_if_exists() {
    local file="$1"

    if [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
    else
        gaudi::warn "Skipping missing step: $file"
    fi
}

# Homebrew on Linux is optional: it is what installs Brewfiles there.
# Homebrew refuses to run as root, so root only gets the distribution packages.
gaudi::offer_linuxbrew() {
    if gaudi::command_exists brew; then
        :
    elif gaudi::is_root; then
        gaudi::warn "Homebrew cannot be installed as root: run Gaudi as a regular user to install Brewfiles"
    elif gaudi::confirm "Install Homebrew on Linux? It is required for Brewfiles." "n"; then
        gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \
            || gaudi::record_failure "Homebrew installation"
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

# Source a file and return the status of its last command, without letting a
# failing command inside it end the whole run. `source file || handle` is not
# enough: bash 3.2 (the bash macOS ships) still exits under `set -e`.
gaudi::source_guarded() {
    local _gaudi_guarded_file="$1"
    local _gaudi_guarded_status=0
    local _gaudi_guarded_errexit="false"

    [[ "$-" == *e* ]] && _gaudi_guarded_errexit="true"
    set +e
    # shellcheck source=/dev/null
    source "$_gaudi_guarded_file"
    _gaudi_guarded_status=$?
    [[ "$_gaudi_guarded_errexit" == "true" ]] && set -e
    return "$_gaudi_guarded_status"
}

# Source every template hook whose file name matches the given pattern.
# A failing hook is recorded, not fatal.
gaudi::run_hooks_matching() {
    local pattern="$1"
    local hook=""

    [[ -d "${GAUDI_TEMPLATES_LOCATION:-}" ]] || return 0
    while IFS= read -r -u 4 hook; do
        [[ -n "$hook" ]] || continue
        # Hooks run real commands, so a dry run must only name them
        if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
            printf "DRY RUN: hook %s\n" "$hook"
            continue
        fi
        gaudi::log "Running hook: $hook"
        gaudi::source_guarded "$hook" || gaudi::record_failure "hook $hook"
    done 4< <(find "$GAUDI_TEMPLATES_LOCATION" -type f -iname "$pattern" -print | sort)
}

_echo() {
    printf "%b" "$*"
}
