#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::run_install_command() {
    local install_command="$1"
    local package_name="$2"
    local -a command_parts=()

    read -r -a command_parts <<< "$install_command"
    [[ ${#command_parts[@]} -gt 0 ]] || return 1

    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        printf "DRY RUN:"
        printf " %q" "${command_parts[@]}" "$package_name"
        printf "\n"
        return 0
    fi

    "${command_parts[@]}" "$package_name"
}

installSoftwareList() {
    local install_command="$1"
    local is_with_prompt="$2"
    local item=""
    shift 2
    local software_list=("$@")

    for item in "${software_list[@]}"; do
        local software=""
        local software_description=""

        [[ -n "$item" ]] || continue
        software="${item%%::*}"
        if [[ "$item" == *"::"* ]]; then
            software_description="${item#*::}"
        fi

        printf "\n%b\n" "Installing ${MAGENTA:-}$software${NC:-}"
        [[ -n "$software_description" ]] && printf "%b\n" "${YELLOW:-}Description:${NC:-} $software_description"

        if [[ "$is_with_prompt" == "true" ]]; then
            gaudi::confirm "Install $software?" "n" || continue
        fi

        gaudi::run_install_command "$install_command" "$software"
    done
}

brew_install_or_upgrade() {
    local package_name="$1"

    if brew list --versions "$package_name" >/dev/null 2>&1; then
        if brew outdated --quiet "$package_name" >/dev/null 2>&1; then
            gaudi::log "Upgrading $package_name"
            brew upgrade "$package_name"
        else
            gaudi::success "$package_name is already current"
        fi
    else
        brew install "$package_name"
    fi
}

brew_tap_or_update() {
    local tap_name="$1"

    if brew tap | grep -Fxq "$tap_name"; then
        gaudi::success "Tap already configured: $tap_name"
    else
        brew tap "$tap_name"
    fi
}

gem_install_or_update() {
    local subcommand="${1:-install}"
    shift || true

    if [[ "$subcommand" == "install" && "$#" -gt 0 ]] && gem list "$1" --installed >/dev/null 2>&1; then
        gem update "$@"
    else
        gem "$subcommand" "$@" --user-install
    fi
}
