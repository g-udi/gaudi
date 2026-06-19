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

    # shellcheck source=/dev/null
    source "$config_file"

    if ! declare -F _command >/dev/null 2>&1; then
        gaudi::warn "Skipping $config_file: _command function is missing"
        return 0
    fi

    _info="${_info:-$(basename "$config_file")}"
    if [[ "$install_all" == "true" ]]; then
        printf "%b\n" "${GREEN:-}${_info}${NC:-}"
        _command
    else
        gaudi::confirm "${GREEN:-}${_info}${NC:-}" "n" && _command
    fi
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

while IFS= read -r config_file; do
    [[ -n "$config_file" ]] || continue
    gaudi::run_configuration "$config_file" "$install_all"
done < <(gaudi::configuration_files)
