#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::run_resolved_command() {
    local command_name="$1"
    local command_path=""
    shift

    command_path="$(gaudi::find_command "$command_name")" || {
        gaudi::error "Required command not found: $command_name"
        return 127
    }

    "$command_path" "$@"
}

# Run a command as root. A minimal Debian (a container, a fresh server) often
# has no sudo and runs as root already, where the command can just be run.
sudo() {
    local sudo_path=""

    if sudo_path="$(gaudi::find_command sudo)"; then
        "$sudo_path" "$@"
        return
    fi

    if gaudi::is_root; then
        "$@"
        return
    fi

    gaudi::error "This step needs root: install sudo or run Gaudi as root"
    return 1
}

brew() {
    gaudi::run_resolved_command brew "$@"
}
