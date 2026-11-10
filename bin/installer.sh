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

    # Iterating "$@" (not a copied array) keeps empty lists safe under
    # `set -u` on the bash 3.2 that ships with macOS
    for item in "$@"; do
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

        # One broken package must not stop the rest of the list
        gaudi::run_install_command "$install_command" "$software" \
            || gaudi::record_failure "$software ($install_command)"
    done
}

# Install everything declared in a Brewfile.
# brew bundle is idempotent and keeps going past individual failures; it only
# reports them through its exit status.
gaudi::bundle_install() {
    local brewfile="$1"
    local -a bundle_args=(bundle install "--file=$brewfile")

    [[ "${GAUDI_BUNDLE_NO_UPGRADE:-false}" == "true" ]] && bundle_args+=(--no-upgrade)

    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        printf "DRY RUN: brew"
        printf " %q" "${bundle_args[@]}"
        printf "\n"
        return 0
    fi

    brew "${bundle_args[@]}"
}

gem_install_or_update() {
    local subcommand="${1:-install}"
    shift || true

    if [[ "$subcommand" == "install" && "$#" -gt 0 ]] && gem list --installed --exact "$1" >/dev/null 2>&1; then
        gem update "$@" --user-install
    else
        gem "$subcommand" "$@" --user-install
    fi
}
