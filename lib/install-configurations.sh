#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"

gaudi::configuration_files() {
    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] || return 0
    find "$GAUDI_TEMPLATES_LOCATION" -type f \
        \( -iname "*.configs.${OS}.sh" -o -iname "*.configs.sh" \) \
        -print | sort
}

gaudi::run_configuration() {
    local config_file="$1"
    local install_all="$2"

    unset _info
    unset -f _command 2>/dev/null || true

    gaudi::source_guarded "$config_file"
    if [[ -n "$gaudi_guarded_failure" ]]; then
        gaudi::record_failure "config $config_file: $gaudi_guarded_failure"
        return 0
    fi

    if ! declare -F _command >/dev/null 2>&1; then
        gaudi::warn "Skipping $config_file: _command function is missing"
        return 0
    fi

    _info="${_info:-$(basename "$config_file")}"
    if [[ "$install_all" == "true" ]]; then
        printf "%b\n" "${GREEN:-}${_info}${NC:-}"
    elif ! gaudi::confirm "${GREEN:-}${_info}${NC:-}" "n"; then
        # Declining one config must not end the run
        return 0
    fi

    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        printf "DRY RUN: config %s\n" "$config_file"
        return 0
    fi

    gaudi::call_guarded "$config_file" _command
    [[ -z "$gaudi_guarded_failure" ]] || gaudi::record_failure "config ${_info}: $gaudi_guarded_failure"
}

if [[ ! -d "$GAUDI_TEMPLATES_LOCATION" ]]; then
    gaudi::warn "Template directory not found: $GAUDI_TEMPLATES_LOCATION"
    return 0
fi

if gaudi::confirm "Install all recommended configs?" "n"; then
    install_all=true
else
    install_all=false
fi

while IFS= read -r -u 3 config_file; do
    [[ -n "$config_file" ]] || continue
    gaudi::run_configuration "$config_file" "$install_all"
done 3< <(gaudi::configuration_files)
