#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::resolved_command_path() {
    gaudi::find_command "$1"
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
