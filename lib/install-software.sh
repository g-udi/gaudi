#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"

# Everything Homebrew can install (formulae, casks, taps, Mac App Store apps,
# npm, go, cargo, uv, VS Code extensions) is declared in Brewfiles.
# The list engine below only remains for managers brew bundle does not cover.
softwareLists=(
    "debian|apt::sudo apt-get install -y"
    "*|gem::gem_install_or_update install"
)

# List types that used to exist and now belong in a Brewfile
legacyListTypes=(tap brew cask mas npm pip go)

gaudi::brewfiles() {
    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] || return 0
    find "$GAUDI_TEMPLATES_LOCATION" -type f \( -name "Brewfile" -o -name "*.Brewfile" \) -print | sort
}

gaudi::brewfile_name() {
    local base="${1##*/}"

    if [[ "$base" == "Brewfile" ]]; then
        printf "default"
    else
        printf "%s" "${base%.Brewfile}"
    fi
}

gaudi::template_files_for_type() {
    local list_type="$1"

    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] || return 0
    find "$GAUDI_TEMPLATES_LOCATION" -type f \
        \( -iname "*.${list_type}.list.sh" -o -iname "*.${list_type}.sh" -o -iname "*.${list_type}-*.list.sh" -o -iname "*.${list_type}-*.sh" \) \
        ! -iname "*.hooks.sh" \
        -print | sort
}

gaudi::installer_available_for_type() {
    case "$1" in
        apt)
            gaudi::command_exists apt-get
            ;;
        gem)
            gaudi::command_exists gem
            ;;
        *)
            return 0
            ;;
    esac
}

gaudi::install_brewfile() {
    local brewfile="$1"
    local name=""
    local title=""
    local description=""

    name="$(gaudi::brewfile_name "$brewfile")"
    title="$(gaudi::metadata_value "$brewfile" "@Name")"
    description="$(gaudi::metadata_value "$brewfile" "@Description")"
    title="${title:-$name}"

    printf "\n%b\n" "Brewfile: ${YELLOW:-}$title${NC:-} ($brewfile)"
    [[ -n "$description" ]] && printf "%b\n" "${MAGENTA:-}$description${NC:-}"
    gaudi::confirm "Install this Brewfile?" "n" || return 0

    # pre.bundle-<name>.hooks.sh, or pre.bundle-<name>.<topic>.hooks.sh for several hooks per Brewfile
    gaudi::run_hooks_matching "pre.bundle-${name}.hooks.sh"
    gaudi::run_hooks_matching "pre.bundle-${name}.*.hooks.sh"
    gaudi::bundle_install "$brewfile" || gaudi::record_failure "some entries in $brewfile (rerun: brew bundle install --file=$brewfile)"
    gaudi::run_hooks_matching "post.bundle-${name}.hooks.sh"
    gaudi::run_hooks_matching "post.bundle-${name}.*.hooks.sh"
}

gaudi::install_list_file() {
    local list_file="$1"
    local list_command="$2"
    local list_type="$3"
    local list_name=""
    local list_title=""
    local list_description=""
    local list_ref=""
    local list_count=0

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

    gaudi::source_guarded "$list_file" || {
        gaudi::record_failure "list $list_file"
        return 0
    }
    list_ref="${list_name}[@]"

    if ! declare -p "$list_name" >/dev/null 2>&1; then
        gaudi::warn "Skipping $list_file: array not defined: $list_name"
        return 0
    fi

    # Expanding an empty array is an error under `set -u` on bash 3.2
    eval "list_count=\${#${list_name}[@]}"
    if [[ "${list_count:-0}" -eq 0 ]]; then
        gaudi::warn "Skipping $list_file: the list is empty"
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

# --- Brewfiles ---------------------------------------------------------------

brewfile_count=0
while IFS= read -r brewfile; do
    [[ -n "$brewfile" ]] || continue
    brewfile_count=$((brewfile_count + 1))
done < <(gaudi::brewfiles)

if [[ "$brewfile_count" -gt 0 ]]; then
    if gaudi::command_exists brew; then
        gaudi::run_hooks_matching "pre.bundle.hooks.sh"
        while IFS= read -r -u 3 brewfile; do
            [[ -n "$brewfile" ]] || continue
            gaudi::install_brewfile "$brewfile"
        done 3< <(gaudi::brewfiles)
        gaudi::run_hooks_matching "post.bundle.hooks.sh"
    else
        gaudi::warn "Skipping $brewfile_count Brewfile(s): Homebrew is not available"
    fi
fi

for legacy_type in "${legacyListTypes[@]}"; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        gaudi::warn "Ignoring $list_file: '$legacy_type' lists moved to Brewfiles (see README)"
    done < <(gaudi::template_files_for_type "$legacy_type")
done

# --- Lists for managers brew bundle does not cover ---------------------------

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

    gaudi::run_hooks_matching "pre.${listType}*.hooks.sh"

    while IFS= read -r -u 3 list_file; do
        [[ -n "$list_file" ]] || continue
        gaudi::install_list_file "$list_file" "$listCommand" "$listType"
    done 3< <(gaudi::template_files_for_type "$listType")

    gaudi::run_hooks_matching "post.${listType}*.hooks.sh"
done
