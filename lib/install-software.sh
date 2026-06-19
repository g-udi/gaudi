#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"

softwareLists=(
    "debian|apt::sudo apt-get install -y"
    "*|tap::brew_tap_or_update"
    "*|brew::brew_install_or_upgrade"
    "osx|mas::mas install"
    "osx|cask::brew install --cask"
    "*|npm::npm install -g"
    "*|pip::python3 -m pip install --upgrade --user"
    "*|go::go install"
    "*|gem::gem_install_or_update install"
)

gaudi::template_files_for_type() {
    local list_type="$1"

    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] || return 0
    find "$GAUDI_TEMPLATES_LOCATION" -type f \
        \( -iname "*.${list_type}.list.sh" -o -iname "*.${list_type}.sh" -o -iname "*.${list_type}-*.list.sh" -o -iname "*.${list_type}-*.sh" \) \
        -print | sort
}

gaudi::run_hooks() {
    local phase="$1"
    local list_type="$2"
    local hook=""

    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] || return 0
    while IFS= read -r hook; do
        [[ -n "$hook" ]] || continue
        gaudi::log "Running hook: $hook"
        # shellcheck source=/dev/null
        source "$hook"
    done < <(find "$GAUDI_TEMPLATES_LOCATION" -type f -iname "${phase}.${list_type}*.hooks.sh" -print | sort)
}

gaudi::installer_available_for_type() {
    case "$1" in
        apt)
            gaudi::command_exists apt-get
            ;;
        brew|tap|cask)
            gaudi::command_exists brew
            ;;
        mas)
            gaudi::command_exists mas
            ;;
        npm)
            gaudi::command_exists npm
            ;;
        pip)
            gaudi::command_exists python3
            ;;
        go)
            gaudi::command_exists go
            ;;
        gem)
            gaudi::command_exists gem
            ;;
        *)
            return 0
            ;;
    esac
}

gaudi::install_list_file() {
    local list_file="$1"
    local list_command="$2"
    local list_type="$3"
    local list_name=""
    local list_title=""
    local list_description=""
    local list_ref=""

    list_name="$(gaudi::metadata_value "$list_file" "@List")"
    list_title="$(gaudi::metadata_value "$list_file" "@Name")"
    list_description="$(gaudi::metadata_value "$list_file" "@Description")"

    if [[ -z "$list_name" ]]; then
        gaudi::warn "Skipping $list_file: missing # @List metadata"
        return 0
    fi

    list_title="${list_title:-$(basename "$list_file")}"

    printf "\n%b\n" "Software list: ${YELLOW:-}$list_title${NC:-} (${list_type})"
    [[ -n "$list_description" ]] && printf "%b\n" "${MAGENTA:-}$list_description${NC:-}"
    gaudi::confirm "Proceed with this list?" "n" || return 0

    # shellcheck source=/dev/null
    source "$list_file"
    list_ref="${list_name}[@]"

    if ! declare -p "$list_name" >/dev/null 2>&1; then
        gaudi::warn "Skipping $list_file: array not defined: $list_name"
        return 0
    fi

    if gaudi::confirm "Install all recommended items from $list_title?" "y"; then
        installSoftwareList "$list_command" "false" "${!list_ref}"
    else
        installSoftwareList "$list_command" "true" "${!list_ref}"
    fi
}

if [[ ! -d "$GAUDI_TEMPLATES_LOCATION" ]]; then
    gaudi::warn "Template directory not found: $GAUDI_TEMPLATES_LOCATION"
    return 0
fi

for item in "${softwareLists[@]}"; do
    operatingSystem="${item%%|*}"
    list="${item%%::*}"
    listType="${list#*|}"
    listCommand="${item#*::}"

    [[ "$operatingSystem" == "$OS" || "$operatingSystem" == "*" ]] || continue

    if ! gaudi::installer_available_for_type "$listType"; then
        gaudi::warn "Skipping $listType lists: required package manager is not available"
        continue
    fi

    gaudi::run_hooks "pre" "$listType"

    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        gaudi::install_list_file "$list_file" "$listCommand" "$listType"
    done < <(gaudi::template_files_for_type "$listType")

    gaudi::run_hooks "post" "$listType"
done
