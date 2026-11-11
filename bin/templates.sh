#!/usr/bin/env bash
# shellcheck shell=bash
# What a templates directory may contain, in one place. Setup, `gaudi check`,
# `gaudi backup`, `gaudi doctor` and the test suite's fake Homebrew all take
# their names, patterns and file lists from here, so they cannot drift apart.
#
# Needs bin/helpers.sh (gaudi::guarded) for gaudi::list_items.
#
# shellcheck disable=SC2034  # the variables are read by the scripts that source this file

# Operating systems Gaudi automates: the values gaudi::detect_os gives OS
gaudi_known_oses="osx debian fedora arch opensuse"
# List types that are installed: the distribution's package manager, and gems
gaudi_list_types="apt dnf pacman zypper gem"
# List types that used to exist and now belong in a Brewfile
gaudi_legacy_list_types="tap brew cask mas npm pip go"

# A package line of a Brewfile: <type> "<name>"[, options]. Homebrew reads a
# Brewfile as Ruby, so single quotes are as good as double quotes.
gaudi_brewfile_entry_re='^[[:space:]]*(tap|brew|cask|mas|vscode|npm|go|cargo|uv|flatpak|winget|krew)[[:space:]]+["'"'"']([^"'"'"']+)["'"'"'](.*)$'
# Every other line Gaudi expects in a Brewfile: blank, a comment, cask_args,
# and the Ruby keywords of a block (if OS.mac? ... else ... end)
gaudi_brewfile_other_re='^[[:space:]]*(#.*|cask_args[[:space:]].*|(if|unless|elsif)[[:space:]].*|(else|end)[[:space:]]*(#.*)?)?$'
# The line that starts the _command function of a configuration script
# (the opening brace may sit on the next line)
gaudi_config_command_re='^[[:space:]]*(function[[:space:]]+_command([[:space:]]*\(\))?|_command[[:space:]]*\(\))([[:space:]]|\{|$)'

# True when the OS that gaudi::detect_os found is one Gaudi automates
gaudi::supported_os() {
    [[ -n "${OS:-}" && " $gaudi_known_oses " == *" $OS "* ]]
}

# The parts of the last line gaudi::brewfile_entry accepted
gaudi_entry_type=""
gaudi_entry_name=""
gaudi_entry_rest=""

# True for a package line of a Brewfile; its parts are left in
# gaudi_entry_type, gaudi_entry_name and gaudi_entry_rest.
gaudi::brewfile_entry() {
    [[ "$1" =~ $gaudi_brewfile_entry_re ]] || return 1
    gaudi_entry_type="${BASH_REMATCH[1]}"
    gaudi_entry_name="${BASH_REMATCH[2]}"
    gaudi_entry_rest="${BASH_REMATCH[3]}"
}

# True for a Brewfile line that is fine without being a package
gaudi::brewfile_other_line() {
    [[ "$1" =~ $gaudi_brewfile_other_re ]]
}

# Every Brewfile of a templates directory: Brewfile or <name>.Brewfile, anywhere
#   gaudi::brewfiles [templates dir]
gaudi::brewfiles() {
    local templates="${1:-${GAUDI_TEMPLATES_LOCATION:-}}"

    [[ -d "$templates" ]] || return 0
    find "$templates" -type f \( -name "Brewfile" -o -name "*.Brewfile" \) -print | sort
}

# The name hooks use for a Brewfile: "core" for core.Brewfile, "default" for Brewfile
gaudi::brewfile_name() {
    local base="${1##*/}"

    if [[ "$base" == "Brewfile" ]]; then
        printf "default"
    else
        printf "%s" "${base%.Brewfile}"
    fi
}

# Every list file of one type
#   gaudi::list_files <type> [templates dir]
gaudi::list_files() {
    local list_type="$1"
    local templates="${2:-${GAUDI_TEMPLATES_LOCATION:-}}"

    [[ -d "$templates" ]] || return 0
    find "$templates" -type f \
        \( -iname "*.${list_type}.list.sh" -o -iname "*.${list_type}.sh" -o -iname "*.${list_type}-*.list.sh" -o -iname "*.${list_type}-*.sh" \) \
        ! -iname "*.hooks.sh" \
        -print | sort
}

# Hook files, optionally only those whose name matches a pattern
#   gaudi::hook_files [name pattern] [templates dir]
gaudi::hook_files() {
    local pattern="${1:-*.hooks.sh}"
    local templates="${2:-${GAUDI_TEMPLATES_LOCATION:-}}"

    [[ -d "$templates" ]] || return 0
    find "$templates" -type f -iname "$pattern" -print | sort
}

# The Brewfile a pre|post.bundle-<name>[.<topic>].hooks.sh file belongs to: the
# longest Brewfile name its file name starts with, so the hook of dev.tools
# is not also taken for the "tools" hook of dev. Prints nothing when no
# Brewfile matches.
#   gaudi::bundle_hook_owner <hook file> [templates dir]
gaudi::bundle_hook_owner() {
    local stem="${1##*/}"
    local owner=""
    local name=""
    local brewfile=""

    stem="${stem#*.bundle-}"
    stem="${stem%.hooks.sh}"
    while IFS= read -r brewfile; do
        [[ -n "$brewfile" ]] || continue
        name="$(gaudi::brewfile_name "$brewfile")"
        if [[ "$stem" == "$name" || "$stem" == "$name."* ]] && [[ ${#name} -gt ${#owner} ]]; then
            owner="$name"
        fi
    done < <(gaudi::brewfiles "${2:-}")

    printf "%s" "$owner"
}

# The list type of an operating system's own package manager (nothing on macOS)
#   gaudi::os_list_type [os]
gaudi::os_list_type() {
    case "${1:-${OS:-}}" in
        debian) printf "apt" ;;
        fedora) printf "dnf" ;;
        arch) printf "pacman" ;;
        opensuse) printf "zypper" ;;
    esac
}

# The program a list type needs
gaudi::list_tool() {
    case "$1" in
        apt) printf "apt-get" ;;
        *) printf "%s" "$1" ;;
    esac
}

# The command that installs one item of a list type (the item is appended)
gaudi::list_install_command() {
    case "$1" in
        apt) printf "sudo apt-get install -y" ;;
        dnf) printf "sudo dnf install -y" ;;
        pacman) printf "sudo pacman -S --noconfirm --needed" ;;
        zypper) printf "sudo zypper --non-interactive install" ;;
        gem) printf "gaudi::gem_install" ;;
        *) return 1 ;;
    esac
}

# Runs inside gaudi::guarded (see gaudi::list_items): source the list file and
# print its array on descriptor 9. The file is sourced in this function, and
# the array is printed before it returns, so an array the file made with
# `declare` or `local` (which belongs to the function that sourced it) counts
# like a plainly assigned one.
gaudi::print_list_items() {
    local _gaudi_list_status=0

    # shellcheck source=/dev/null
    source "$gaudi_list_file"
    _gaudi_list_status=$?
    [[ "$_gaudi_list_status" -eq 0 ]] || return "$_gaudi_list_status"
    [[ -z "$gaudi_guarded_exited$gaudi_guarded_error" ]] || return 0

    if ! declare -p "$gaudi_list_name" >/dev/null 2>&1; then
        printf "missing\n" >&9
        return 0
    fi
    printf "ok\n" >&9
    # Expanding an empty array is an error under `set -u` on bash 3.2
    eval "[[ \${#${gaudi_list_name}[@]} -eq 0 ]] || printf '%s\\n' \"\${${gaudi_list_name}[@]}\" >&9"
}

# Read the array a list file defines. Prints a first line saying how it went:
#   ok                 then the items, one per line (none for an empty array)
#   failed <reason>    the file failed (see gaudi::guarded for what counts)
#   missing            the file does not define the array
# The file runs in a subshell: nothing it sets reaches the caller, and what it
# prints goes to stderr.
#
# Always returns 0, and has to be called as a plain statement or a plain
# assignment (`output="$(gaudi::list_items ...)"`), never from a condition or
# an `||` list: there bash would not report the file's failing commands.
#   gaudi::list_items <file> <array name>
gaudi::list_items() {
    if ! [[ "$2" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        printf "missing\n"
        return 0
    fi
    (
        # A subshell still lists the traps of the shell it came from, and
        # gaudi::guarded puts back what it finds listed: without this, the
        # caller's EXIT trap would run when this subshell ends
        trap - EXIT ERR
        exec 9>&1 1>&2
        gaudi_list_file="$1"
        gaudi_list_name="$2"
        gaudi::guarded "$1" gaudi::print_list_items
        [[ -z "$gaudi_guarded_failure" ]] || printf "failed %s\n" "$gaudi_guarded_failure" >&9
        exit 0
    )
}

# The same answer without running the file, for a dry run: only the array
# itself, `<name>=( ... )` written out in the file, is evaluated. "missing"
# when the file has no such block (the array is built by code).
#   gaudi::list_items_static <file> <array name>
gaudi::list_items_static() {
    local block=""

    if [[ "$2" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        block="$(awk -v name="$2" '
            !found && $0 ~ ("^[ \t]*(declare[ \t]+(-[A-Za-z]+[ \t]+)*)?" name "=\\(") { found = 1 }
            found { print; if ($0 ~ /\)[ \t]*(#.*)?$/) exit }
        ' "$1")"
    fi
    if [[ -z "$block" ]]; then
        printf "missing\n"
        return 0
    fi
    (
        if ! eval "$block" 2>/dev/null || ! declare -p "$2" >/dev/null 2>&1; then
            printf "missing\n"
            exit 0
        fi
        printf "ok\n"
        eval "[[ \${#${2}[@]} -eq 0 ]] || printf '%s\\n' \"\${${2}[@]}\""
    )
}

# True when a configuration script defines _command, judged from its text:
# `gaudi check` and a dry run do not run the script to find out
gaudi::config_defines_command() {
    grep -Eq "$gaudi_config_command_re" "$1"
}

# What a configuration script shows in its prompt, read from its `_info=` line
# without running the script (empty when it has none)
gaudi::config_info() {
    local info=""

    info="$(sed -n 's/^[[:space:]]*_info=//p' "$1" | head -n 1)"
    case "$info" in
        \"*\") info="${info#\"}"; info="${info%\"}" ;;
        \'*\') info="${info#\'}"; info="${info%\'}" ;;
    esac
    printf "%s" "$info"
}

# Every dotfiles.list of a templates directory (backup uses the first one)
#   gaudi::dotfiles_lists [templates dir]
gaudi::dotfiles_lists() {
    local templates="${1:-${GAUDI_TEMPLATES_LOCATION:-}}"

    [[ -d "$templates" ]] || return 0
    find "$templates" -type f -name "dotfiles.list" -print | sort
}

# The entries of a dotfiles.list as "<line number><TAB><entry>": comments and
# surrounding whitespace removed, blank lines left out. Whether an entry is an
# acceptable path is gaudi::dotfile_path's call.
gaudi::dotfiles_list_entries() {
    local entry=""
    local line_number=0

    while IFS= read -r entry || [[ -n "$entry" ]]; do
        line_number=$((line_number + 1))
        entry="${entry%%#*}"
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        [[ -n "$entry" ]] || continue
        printf "%s\t%s\n" "$line_number" "$entry"
    done < "$1"
}
