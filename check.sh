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
KNOWN_OSES="osx debian fedora arch opensuse"
LIST_TYPES="apt dnf pacman zypper gem"
LEGACY_TYPES="tap brew cask mas npm pip go"
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

list_files_for() {
    find "$TEMPLATES" -type f \
        \( -iname "*.$1.list.sh" -o -iname "*.$1.sh" -o -iname "*.$1-*.list.sh" -o -iname "*.$1-*.sh" \) \
        ! -iname "*.hooks.sh" -print | sort
}

# --- Brewfiles -----------------------------------------------------------------

entry_re='^[[:space:]]*(tap|brew|cask|mas|vscode|npm|go|cargo|uv|whalebrew|flatpak|krew)[[:space:]]+"([^"]+)"(.*)$'
other_re='^[[:space:]]*(cask_args|#|$)'
: > "$SCRATCH/brewfile-names"
: > "$SCRATCH/entries"

while IFS= read -r brewfile; do
    [[ -n "$brewfile" ]] || continue
    checked=$((checked + 1))
    base="${brewfile##*/}"
    if [[ "$base" == "Brewfile" ]]; then
        printf "default\n" >> "$SCRATCH/brewfile-names"
    else
        printf "%s\n" "${base%.Brewfile}" >> "$SCRATCH/brewfile-names"
    fi

    if gaudi::command_exists brew && ! brew bundle list --all "--file=$brewfile" >/dev/null 2>&1; then
        problem "$brewfile" "Homebrew cannot read this Brewfile (try: brew bundle list --file=$brewfile)"
    fi

    line_number=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))
        if [[ "$line" =~ $entry_re ]]; then
            # Copied out first: the next regex match replaces BASH_REMATCH
            entry_type="${BASH_REMATCH[1]}"
            entry_name="${BASH_REMATCH[2]}"
            entry_rest="${BASH_REMATCH[3]}"
            printf "%s %s\t%s\n" "$entry_type" "$entry_name" "$brewfile" >> "$SCRATCH/entries"
            if [[ "$entry_type" == "mas" && ! "$entry_rest" =~ id:[[:space:]]*[0-9]+ ]]; then
                problem "$brewfile" "line $line_number: mas \"$entry_name\" needs an id (mas \"Name\", id: 123)"
            fi
        elif [[ ! "$line" =~ $other_re ]]; then
            concern "$brewfile" "line $line_number is not a package entry: $line"
        fi
    done < "$brewfile"
done < <(find "$TEMPLATES" -type f \( -name "Brewfile" -o -name "*.Brewfile" \) -print | sort)

while IFS= read -r duplicate; do
    [[ -n "$duplicate" ]] || continue
    first_file="$(grep -F -- "$duplicate"$'\t' "$SCRATCH/entries" | head -n 1 | cut -f 2)"
    concern "$first_file" "$duplicate is listed more than once"
done < <(cut -f 1 "$SCRATCH/entries" | sort | uniq -d)

# --- lists ---------------------------------------------------------------------

for list_type in $LIST_TYPES; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        checked=$((checked + 1))
        list_name="$(gaudi::metadata_value "$list_file" "@List")"
        if ! parses "$list_file"; then
            problem "$list_file" "is not valid Bash"
        elif [[ -z "$list_name" ]]; then
            problem "$list_file" "has no '# @List: <array name>' line, so it is skipped"
        elif ! bash -c 'source "$1" >/dev/null 2>&1; declare -p "$2" >/dev/null 2>&1' _ "$list_file" "$list_name"; then
            problem "$list_file" "does not define the array '$list_name' named by @List"
        elif [[ "$(bash -c 'source "$1" >/dev/null 2>&1; eval "printf %s \${#$2[@]}"' _ "$list_file" "$list_name")" == "0" ]]; then
            concern "$list_file" "the list is empty"
        fi
    done < <(list_files_for "$list_type")
done

for list_type in $LEGACY_TYPES; do
    while IFS= read -r list_file; do
        [[ -n "$list_file" ]] || continue
        checked=$((checked + 1))
        problem "$list_file" "'$list_type' lists are no longer installed: move the entries to a Brewfile"
    done < <(list_files_for "$list_type")
done

# --- hooks ---------------------------------------------------------------------

hook_is_known() {
    local base="$1"
    local phase="${base%%.*}"
    local name=""
    local list_type=""

    [[ "$phase" == "pre" || "$phase" == "post" ]] || return 1
    [[ "$base" == "$phase.bundle.hooks.sh" ]] && return 0

    for list_type in $LIST_TYPES; do
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
done < <(find "$TEMPLATES" -type f -name "*.hooks.sh" -print | sort)

# --- configuration scripts -----------------------------------------------------

command_re='^[[:space:]]*(function[[:space:]]+)?_command[[:space:]]*(\(\))?[[:space:]]*\{'

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
    if [[ -n "$config_os" && " $KNOWN_OSES " != *" $config_os "* ]]; then
        problem "$config" "never runs: '$config_os' is not one of: $KNOWN_OSES"
    fi
    if ! parses "$config"; then
        problem "$config" "is not valid Bash"
        continue
    fi
    grep -Eq "$command_re" "$config" || problem "$config" "does not define _command, so it is skipped"
    grep -Eq '^[[:space:]]*_info=' "$config" || concern "$config" "has no _info: the file name is shown instead"
done < <(find "$TEMPLATES" -type f -name "*.sh" ! -name "*.hooks.sh" ! -name "*.list.sh" -print | sort)

# --- dotfiles --------------------------------------------------------------------

while IFS= read -r dotfiles_list; do
    [[ -n "$dotfiles_list" ]] || continue
    checked=$((checked + 1))
    line_number=0
    while IFS= read -r entry || [[ -n "$entry" ]]; do
        line_number=$((line_number + 1))
        entry="${entry%%#*}"
        entry="${entry#"${entry%%[![:space:]]*}"}"
        [[ -n "$entry" ]] || continue
        if ! gaudi::dotfile_path "$entry" >/dev/null; then
            problem "$dotfiles_list" "line $line_number: '$entry' must be a path inside the home directory, written relative to it"
        fi
    done < "$dotfiles_list"
done < <(find "$TEMPLATES" -type f -name "dotfiles.list" -print | sort)

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
