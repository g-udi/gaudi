#!/usr/bin/env bash
# shellcheck shell=bash
# Check a templates directory before trusting it with a machine:
#
#   gaudi check [templates-dir] [--online]
#
# Errors are things that will not work (a Brewfile Homebrew cannot read, a
# hook or config whose name means it never runs, a list without its array).
# Warnings are things worth a look. --online also asks Homebrew whether every
# formula and cask still exists (slow: one lookup per package).
set -uo pipefail

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/colors.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/helpers.sh"
# shellcheck source=bin/templates.sh
source "$SOURCE_LOCATION/bin/templates.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/commands.sh"

TEMPLATES=""
ONLINE="false"
for argument in "$@"; do
    case "$argument" in
        --online) ONLINE="true" ;;
        -h|--help)
            printf "Usage: gaudi check [templates-dir] [--online]\n"
            exit 0
            ;;
        -*)
            printf "Unknown option: %s\n" "$argument" >&2
            exit 64
            ;;
        *) TEMPLATES="$argument" ;;
    esac
done
TEMPLATES="${TEMPLATES:-${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$SOURCE_LOCATION}/templates}}"

if [[ ! -d "$TEMPLATES" ]]; then
    gaudi::error "Templates directory not found: $TEMPLATES"
    exit 1
fi
TEMPLATES="$(cd "$TEMPLATES" && pwd)"

errors=0
warnings=0
checked=0
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/gaudi-check.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

relative() {
    printf "%s" "${1#"$TEMPLATES"/}"
}

problem() {
    errors=$((errors + 1))
    printf "%b\n" "${RED:-}error${NC:-}    $(relative "$1"): $2"
}

concern() {
    warnings=$((warnings + 1))
    printf "%b\n" "${YELLOW:-}warning${NC:-}  $(relative "$1"): $2"
}

parses() {
    bash -n "$1" 2>/dev/null
}

# --- Brewfiles -----------------------------------------------------------------
# What counts as a Brewfile, a package line, a list or a hook is defined in
# bin/templates.sh, which setup reads too.

: > "$SCRATCH/brewfile-names"
: > "$SCRATCH/entries"

while IFS= read -r brewfile; do
    [[ -n "$brewfile" ]] || continue
    checked=$((checked + 1))
    printf "%s\n" "$(gaudi::brewfile_name "$brewfile")" >> "$SCRATCH/brewfile-names"

    if gaudi::command_exists brew && ! brew bundle list --all "--file=$brewfile" >/dev/null 2>&1; then
        problem "$brewfile" "Homebrew cannot read this Brewfile (try: brew bundle list --file=$brewfile)"
    fi

    line_number=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        if gaudi::brewfile_entry "$line"; then
            printf "%s %s\t%s\n" "$gaudi_entry_type" "$gaudi_entry_name" "$brewfile" >> "$SCRATCH/entries"
            if [[ "$gaudi_entry_type" == "mas" && ! "$gaudi_entry_rest" =~ id:[[:space:]]*[0-9]+ ]]; then
                problem "$brewfile" "line $line_number: mas \"$gaudi_entry_name\" needs an id (mas \"Name\", id: 123)"
            fi
        elif ! gaudi::brewfile_other_line "$line"; then
            concern "$brewfile" "line $line_number is not a package entry: $line"
        fi
    done < "$brewfile"
done < <(gaudi::brewfiles "$TEMPLATES")

while IFS= read -r duplicate; do
    [[ -n "$duplicate" ]] || continue
    first_file="$(grep -F -- "$duplicate"$'\t' "$SCRATCH/entries" | head -n 1 | cut -f 2)"
    concern "$first_file" "$duplicate is listed more than once"
done < <(cut -f 1 "$SCRATCH/entries" | sort | uniq -d)

# --- lists ---------------------------------------------------------------------

for list_type in $gaudi_list_types; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        checked=$((checked + 1))
        list_name="$(gaudi::metadata_value "$list_file" "@List")"
        if ! parses "$list_file"; then
            problem "$list_file" "is not valid Bash"
            continue
        elif [[ -z "$list_name" ]]; then
            problem "$list_file" "has no '# @List: <array name>' line, so it is skipped"
            continue
        fi

        # Read the way setup reads it, so both agree on what the list holds
        list_output="$(gaudi::list_items "$list_file" "$list_name" 2>/dev/null)"
        case "$list_output" in
            ok) concern "$list_file" "the list is empty" ;;
            ok*) ;;
            failed*) concern "$list_file" "could not be read on this machine (${list_output#failed }): setup reports a list that fails as a failure" ;;
            *) problem "$list_file" "does not define the array '$list_name' named by @List" ;;
        esac
    done < <(gaudi::list_files "$list_type" "$TEMPLATES")
done

for list_type in $gaudi_legacy_list_types; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        checked=$((checked + 1))
        problem "$list_file" "'$list_type' lists are no longer installed: move the entries to a Brewfile"
    done < <(gaudi::list_files "$list_type" "$TEMPLATES")
done

# --- hooks ---------------------------------------------------------------------

hook_is_known() {
    local base="$1"
    local phase="${base%%.*}"
    local name=""
    local list_type=""

    [[ "$phase" == "pre" || "$phase" == "post" ]] || return 1
    [[ "$base" == "$phase.bundle.hooks.sh" ]] && return 0

    for list_type in $gaudi_list_types; do
        [[ "$base" == "$phase.$list_type"*".hooks.sh" ]] && return 0
    done

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        [[ "$base" == "$phase.bundle-$name.hooks.sh" || "$base" == "$phase.bundle-$name."*".hooks.sh" ]] && return 0
    done < "$SCRATCH/brewfile-names"

    return 1
}

while IFS= read -r hook; do
    [[ -n "$hook" ]] || continue
    checked=$((checked + 1))
    base="${hook##*/}"
    parses "$hook" || problem "$hook" "is not valid Bash"
    if ! hook_is_known "$base"; then
        if [[ "$base" == *".bundle-"* ]]; then
            problem "$hook" "never runs: no Brewfile matches its name (have: $(tr '\n' ' ' < "$SCRATCH/brewfile-names"))"
        else
            problem "$hook" "never runs: the name is not pre|post.bundle[-<Brewfile>[.<topic>]].hooks.sh or pre|post.<apt|dnf|pacman|zypper|gem>.hooks.sh"
        fi
    fi
done < <(gaudi::hook_files "*.hooks.sh" "$TEMPLATES")

# --- configuration scripts -----------------------------------------------------

while IFS= read -r config; do
    [[ -n "$config" ]] || continue
    base="${config##*/}"
    case "$base" in
        *.configs.sh)
            config_os=""
            ;;
        *.configs.*.sh)
            config_os="${base%.sh}"
            config_os="${config_os##*.configs.}"
            ;;
        *)
            # Only files that sit in a configs directory are expected to be configs
            if [[ "$config" == */configs/* ]]; then
                checked=$((checked + 1))
                problem "$config" "never runs: configs are named <name>.configs.sh or <name>.configs.<os>.sh"
            fi
            continue
            ;;
    esac

    checked=$((checked + 1))
    if [[ -n "$config_os" && " $gaudi_known_oses " != *" $config_os "* ]]; then
        problem "$config" "never runs: '$config_os' is not one of: $gaudi_known_oses"
    fi
    if ! parses "$config"; then
        problem "$config" "is not valid Bash"
        continue
    fi
    gaudi::config_defines_command "$config" || problem "$config" "does not define _command, so it is skipped"
    grep -Eq '^[[:space:]]*_info=' "$config" || concern "$config" "has no _info: the file name is shown instead"
done < <(find "$TEMPLATES" -type f -name "*.sh" ! -name "*.hooks.sh" ! -name "*.list.sh" -print | sort)

# --- dotfiles --------------------------------------------------------------------

while IFS= read -r dotfiles_list; do
    [[ -n "$dotfiles_list" ]] || continue
    checked=$((checked + 1))
    while IFS=$'\t' read -r line_number entry; do
        if ! gaudi::dotfile_path "$entry" >/dev/null; then
            problem "$dotfiles_list" "line $line_number: '$entry' must be a path inside the home directory, written relative to it"
        fi
    done < <(gaudi::dotfiles_list_entries "$dotfiles_list")
done < <(gaudi::dotfiles_lists "$TEMPLATES")

# --- online: does Homebrew still have every package? ------------------------------

if [[ "$ONLINE" == "true" ]]; then
    if ! gaudi::command_exists brew; then
        gaudi::warn "--online needs Homebrew: skipped"
    else
        tapped="$(brew tap 2>/dev/null || true)"
        while IFS=$'\t' read -r entry brewfile; do
            entry_type="${entry%% *}"
            entry_name="${entry#* }"

            # owner/tap/name: Homebrew can only look it up when that tap is installed here
            if [[ "$entry_name" == */*/* ]]; then
                entry_tap="${entry_name%/*}"
                if ! grep -Fxq -- "$entry_tap" <<< "$tapped"; then
                    concern "$brewfile" "$entry_name cannot be verified: the tap $entry_tap is not installed on this machine"
                    continue
                fi
            fi

            case "$entry_type" in
                brew) info="$(brew info --formula "$entry_name" 2>&1)" || { problem "$brewfile" "formula $entry_name was not found in Homebrew"; continue; } ;;
                cask) info="$(brew info --cask "$entry_name" 2>&1)" || { problem "$brewfile" "cask $entry_name was not found in Homebrew"; continue; } ;;
                *) continue ;;
            esac
            # Homebrew words a cask that was deprecated first as
            # "Deprecated because ...! It was disabled on <date>."
            if [[ "$info" == *"Disabled because"* || "$info" == *"It was disabled on"* ]]; then
                problem "$brewfile" "$entry_name is disabled in Homebrew and can no longer be installed"
            elif [[ "$info" == *"Deprecated because"* ]]; then
                concern "$brewfile" "$entry_name is deprecated in Homebrew and will stop installing"
            fi
        done < "$SCRATCH/entries"
    fi
fi

# --- summary ---------------------------------------------------------------------

printf "\nChecked %s file(s) in %s: %s error(s), %s warning(s)\n" "$checked" "$TEMPLATES" "$errors" "$warnings"
[[ "$errors" -eq 0 ]]
