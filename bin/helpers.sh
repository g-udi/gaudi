#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::command_exists() {
    local command_name="$1"
    local candidate=""

    type -P "$command_name" >/dev/null 2>&1 && return 0

    for candidate in \
        "/opt/homebrew/bin/$command_name" \
        "/usr/local/bin/$command_name" \
        "/home/linuxbrew/.linuxbrew/bin/$command_name" \
        "$HOME/.linuxbrew/bin/$command_name"; do
        [[ -x "$candidate" ]] && return 0
    done

    return 1
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
            elif gaudi::command_exists yum; then
                OS="centos"
            elif gaudi::command_exists zypper; then
                OS="opensuse"
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
        osx|debian)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_shell_type() {
    local shell_name="${GAUDI_TARGET_SHELL:-}"

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

    case "$shell_name" in
        bash)
            GAUDI_SHELL="bash"
            if [[ "${OS:-}" == "osx" ]]; then
                GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.bash_profile}"
            else
                GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.bashrc}"
            fi
            ;;
        zsh)
            GAUDI_SHELL="zsh"
            GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.zshrc}"
            ;;
        fish)
            GAUDI_SHELL="fish"
            GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.config/fish/config.fish}"
            ;;
        sh|dash|ksh)
            GAUDI_SHELL="$shell_name"
            GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.profile}"
            ;;
        *)
            GAUDI_SHELL="$shell_name"
            GAUDI_SHELL_PROFILE="${GAUDI_SHELL_PROFILE:-$HOME/.profile}"
            ;;
    esac

    export GAUDI_SHELL GAUDI_SHELL_PROFILE
}

read_answer() {
    local options="${1:-yYnN}"
    local default="${2:-}"
    local input=""

    if [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]]; then
        printf "y"
        return 0
    fi

    if [[ ! -t 0 && -n "$default" ]]; then
        printf "%s" "$default"
        return 0
    fi

    while [[ -z "$input" ]]; do
        IFS= read -r -n 1 input || true
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

read_email() {
    local input=""
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

    while [[ -z "$input" ]]; do
        IFS= read -r input
        if ! [[ "$input" =~ $email_regex ]]; then
            gaudi::error "Please enter a valid email address"
            input=""
        fi
    done

    printf "%s" "$input"
}

read_git_url() {
    local input=""
    local default="${1:-https://github.com/g-udi/gaudi-templates.git}"

    while [[ -z "$input" ]]; do
        IFS= read -e -r input || true
        input="${input:-$default}"
        if ! GIT_TERMINAL_PROMPT=0 git ls-remote "$input" >/dev/null 2>&1; then
            gaudi::error "Unable to access repository: $input"
            printf "%b" "${YELLOW:-}Enter a reachable Git URL:${NC:-} " >&2
            input=""
        fi
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

    if [[ "${GAUDI_SHELL:-}" == "fish" ]]; then
        printf "contains -- \"%s\" \\$PATH; or set -gx PATH \"%s\" \\$PATH" "$bin_dir" "$bin_dir"
    else
        printf "export PATH=\"%s:\\$PATH\"" "$bin_dir"
    fi
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
        gaudi::append_once "$GAUDI_SHELL_PROFILE" "$path_line"
        gaudi::warn "$bin_dir was added to $GAUDI_SHELL_PROFILE. Restart your shell or source that file before using gaudi directly."
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

_echo() {
    printf "%b" "$*"
}
