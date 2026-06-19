#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::resolved_command_path() {
    local command_name="$1"
    local candidate=""

    candidate="$(type -P "$command_name" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        printf "%s" "$candidate"
        return 0
    fi

    for candidate in \
        "/opt/homebrew/bin/$command_name" \
        "/usr/local/bin/$command_name" \
        "/home/linuxbrew/.linuxbrew/bin/$command_name" \
        "$HOME/.linuxbrew/bin/$command_name"; do
        if [[ -x "$candidate" ]]; then
            printf "%s" "$candidate"
            return 0
        fi
    done

    return 1
}

gaudi::run_resolved_command() {
    local command_name="$1"
    local command_path=""
    shift

    command_path="$(gaudi::resolved_command_path "$command_name")" || {
        gaudi::error "Required command not found: $command_name"
        return 127
    }

    "$command_path" "$@"
}

brew() {
    gaudi::run_resolved_command brew "$@"
}

mas() {
    gaudi::run_resolved_command mas "$@"
}

npm() {
    gaudi::run_resolved_command npm "$@"
}
