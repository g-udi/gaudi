#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090
# shellcheck disable=SC2154  # gaudi_entry_* and gaudi_legacy_list_types come from bin/templates.sh

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"

# Everything Homebrew can install (formulae, casks, taps, Mac App Store apps,
# npm, go, cargo, uv, VS Code extensions) is declared in Brewfiles.
# The list engine below only remains for managers brew bundle does not cover.
# Which files are Brewfiles and lists, and what installs a list, is defined in
# bin/templates.sh.

# Ask about every entry of a Brewfile and write the accepted ones to a new
# file. Taps, cask_args, comments, the keywords of a Ruby block and anything
# else that is not a package are kept, so the result is still a valid Brewfile.
#   gaudi::pick_brewfile_entries <brewfile> <output file>
gaudi::pick_brewfile_entries() {
    local brewfile="$1"
    local picked="$2"
    local line=""
    local description=""
    local comment_re='^[[:space:]]*#[[:space:]]*(.*)$'

    : > "$picked"
    while IFS= read -r -u 5 line || [[ -n "$line" ]]; do
        # A tap is not a package: it is kept, like every other line
        if gaudi::brewfile_entry "$line" && [[ "$gaudi_entry_type" != "tap" ]]; then
            printf "\n%b\n" "${MAGENTA:-}${gaudi_entry_name}${NC:-} (${gaudi_entry_type})"
            [[ -n "$description" ]] && printf "%b\n" "${YELLOW:-}Description:${NC:-} $description"
            if gaudi::confirm "Install ${gaudi_entry_name}?" "n"; then
                printf "%s\n" "$line" >> "$picked"
            fi
            description=""
            continue
        fi

        if [[ "$line" =~ $comment_re ]]; then
            description="${BASH_REMATCH[1]}"
        else
            description=""
        fi
        printf "%s\n" "$line" >> "$picked"
    done 5< "$brewfile"
}

gaudi::install_brewfile() {
    local brewfile="$1"
    local name=""
    local title=""
    local description=""
    local to_install="$brewfile"
    local picked=""

    name="$(gaudi::brewfile_name "$brewfile")"
    title="$(gaudi::metadata_value "$brewfile" "@Name")"
    description="$(gaudi::metadata_value "$brewfile" "@Description")"
    title="${title:-$name}"

    printf "\n%b\n" "Brewfile: ${YELLOW:-}$title${NC:-} ($brewfile)"
    [[ -n "$description" ]] && printf "%b\n" "${MAGENTA:-}$description${NC:-}"
    gaudi::confirm "Install this Brewfile?" "n" || return 0

    if ! gaudi::confirm "Install everything in $title?" "y"; then
        picked="$(mktemp "${TMPDIR:-/tmp}/gaudi-picked.XXXXXX")"
        gaudi::pick_brewfile_entries "$brewfile" "$picked"
        to_install="$picked"
    fi

    gaudi::run_bundle_hooks pre "$name"
    gaudi::bundle_install "$to_install" || gaudi::record_failure "some entries in $brewfile (rerun: brew bundle install --file=$brewfile)"
    gaudi::run_bundle_hooks post "$name"

    [[ -n "$picked" ]] && rm -f "$picked"
    return 0
}

gaudi::install_list_file() {
    local list_file="$1"
    local list_type="$2"
    local list_command=""
    local list_name=""
    local list_title=""
    local list_description=""
    local list_output=""
    local list_result=""
    local item=""
    local -a list_items=()

    list_command="$(gaudi::list_install_command "$list_type")" || return 0
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

    # The list file runs in a subshell and only its items come back. A dry
    # run does not run it at all: it reads the array as written in the file.
    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        list_output="$(gaudi::list_items_static "$list_file" "$list_name")"
    else
        list_output="$(gaudi::list_items "$list_file" "$list_name")"
    fi

    # The first line says how reading went, the rest are the items
    while IFS= read -r item; do
        if [[ -z "$list_result" ]]; then
            list_result="$item"
        elif [[ -n "$item" ]]; then
            list_items+=("$item")
        fi
    done <<< "$list_output"

    case "$list_result" in
        ok) ;;
        failed*)
            gaudi::record_failure "list $list_file: ${list_result#failed }"
            return 0
            ;;
        *)
            if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
                printf "DRY RUN: list %s is not read: its %s array is built by code, which a dry run does not execute\n" "$list_file" "$list_name"
            else
                gaudi::warn "Skipping $list_file: array not defined: $list_name"
            fi
            return 0
            ;;
    esac

    if [[ ${#list_items[@]} -eq 0 ]]; then
        gaudi::warn "Skipping $list_file: the list is empty"
        return 0
    fi

    if gaudi::confirm "Install all recommended items from $list_title?" "y"; then
        gaudi::install_list_items "$list_command" "false" "${list_items[@]}"
    else
        gaudi::install_list_items "$list_command" "true" "${list_items[@]}"
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

for list_type in $gaudi_legacy_list_types; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        gaudi::warn "Ignoring $list_file: '$list_type' lists moved to Brewfiles (see README)"
    done < <(gaudi::list_files "$list_type")
done

# --- Lists for managers brew bundle does not cover ---------------------------
# The package manager of this operating system, then gems

for list_type in $(gaudi::os_list_type) gem; do
    if ! gaudi::command_exists "$(gaudi::list_tool "$list_type")"; then
        gaudi::warn "Skipping $list_type lists: required package manager is not available"
        continue
    fi

    gaudi::run_hooks_matching "pre.${list_type}*.hooks.sh"

    while IFS= read -r -u 3 list_file; do
        [[ -n "$list_file" ]] || continue
        gaudi::install_list_file "$list_file" "$list_type"
    done 3< <(gaudi::list_files "$list_type")

    gaudi::run_hooks_matching "post.${list_type}*.hooks.sh"
done
