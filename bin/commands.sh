#!/usr/bin/env bash
# shellcheck shell=bash

# @function get_bin_path
# @description Returns the appropriate bin path based on chip type
function get_bin_path {
    if [[ $(sysctl -n machdep.cpu.brand_string) == *Intel* ]]; then
        echo "/usr/local/bin"
    else
        echo "/opt/homebrew/bin"
    fi
}

# @function create_alias
# @description Creates an alias function for the given command
function create_alias {
    local cmd="$1"
    eval "function $cmd {
        $(get_bin_path)/$cmd \"\$@\"
    }"
}

# Create aliases for brew, mas, and npm
create_alias brew
create_alias mas
create_alias npm