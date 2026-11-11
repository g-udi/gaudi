#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/colors.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/helpers.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/templates.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/commands.sh"

usage() {
    printf "Usage: gaudi backup [output-dir]\n"
}

BACKUP_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --)
            # Everything after -- is a directory, even one that starts with a dash
            shift
            [[ $# -eq 0 ]] || BACKUP_DIR="$1"
            ;;
        -*)
            printf "Unknown option: %s\n" "$1" >&2
            usage >&2
            exit 64
            ;;
        *)
            BACKUP_DIR="$1"
            ;;
    esac
    [[ $# -eq 0 ]] || shift
done
BACKUP_DIR="${BACKUP_DIR:-$PWD/backup}"
# An absolute path can never be taken for an option by the tools below
[[ "$BACKUP_DIR" == /* ]] || BACKUP_DIR="$PWD/$BACKUP_DIR"
GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$SOURCE_LOCATION}/templates}"
mkdir -p -- "$BACKUP_DIR"

# Write a Gaudi list file from package names on stdin.
#   write_list <file> <array name>
write_list() {
    local file="$1"
    local list_name="$2"
    local package_name=""

    {
        printf "# @Name: Default\n# @List: %s\n%s=(\n" "$list_name" "$list_name"
        while IFS= read -r package_name; do
            [[ -n "$package_name" ]] || continue
            printf '  "%s"\n' "$package_name"
        done
        printf ")\n"
    } > "$file" || return 1
    gaudi::success "Wrote $file"
}

# One Brewfile covers taps, formulae, casks, Mac App Store apps, VS Code
# extensions and the npm/go/cargo/uv packages Homebrew knows how to track.
backup_bundle() {
    local file="$BACKUP_DIR/Brewfile"

    if ! gaudi::command_exists brew; then
        gaudi::warn "Skipping Brewfile backup: Homebrew is not installed"
        return 0
    fi

    if ! brew bundle dump --force "--file=$file"; then
        gaudi::record_failure "brew bundle dump"
        return 0
    fi

    # Current Homebrew writes a description above each entry by default and
    # rejects --describe; older versions only describe when asked to.
    if ! grep -q '^#' "$file" && brew bundle dump --describe --force "--file=$file.described" >/dev/null 2>&1; then
        mv "$file.described" "$file"
    fi
    rm -f "$file.described"

    gaudi::success "Wrote $file"
    return 0
}

# The package queries below are captured before anything is written: a query
# that fails is recorded and leaves no list behind, instead of ending the
# backup (`set -e`) or passing for a machine with no packages.

# Only packages the user asked for, not the whole base system
backup_apt() {
    local packages=""

    if ! gaudi::command_exists apt-mark; then
        gaudi::warn "Skipping apt backup: apt-mark is not available"
        return 0
    fi

    if ! packages="$(apt-mark showmanual 2>/dev/null)"; then
        gaudi::record_failure "apt backup: apt-mark showmanual"
        return 0
    fi
    printf "%s\n" "$packages" | sort | write_list "$BACKUP_DIR/default.apt.list.sh" aptList
}

backup_dnf() {
    local packages=""

    if ! gaudi::command_exists dnf; then
        gaudi::warn "Skipping dnf backup: dnf is not available"
        return 0
    fi

    if ! packages="$(dnf repoquery --userinstalled --queryformat '%{name}\n' 2>/dev/null)"; then
        gaudi::record_failure "dnf backup: dnf repoquery --userinstalled"
        return 0
    fi
    printf "%s\n" "$packages" | sort -u | write_list "$BACKUP_DIR/default.dnf.list.sh" dnfList
}

backup_pacman() {
    local packages=""

    if ! gaudi::command_exists pacman; then
        gaudi::warn "Skipping pacman backup: pacman is not available"
        return 0
    fi

    # -Qqe: explicitly installed packages, names only
    if ! packages="$(pacman -Qqe 2>/dev/null)"; then
        gaudi::record_failure "pacman backup: pacman -Qqe"
        return 0
    fi
    printf "%s\n" "$packages" | sort -u | write_list "$BACKUP_DIR/default.pacman.list.sh" pacmanList
}

backup_zypper() {
    local packages=""

    if ! gaudi::command_exists zypper; then
        gaudi::warn "Skipping zypper backup: zypper is not available"
        return 0
    fi

    # The table is "status | repository | name | version | arch"
    if ! packages="$(zypper --quiet packages --userinstalled 2>/dev/null)"; then
        gaudi::record_failure "zypper backup: zypper packages --userinstalled"
        return 0
    fi
    printf "%s\n" "$packages" \
        | awk -F'|' 'NF >= 5 && $1 ~ /i/ { gsub(/^[ \t]+|[ \t]+$/, "", $3); if ($3 != "" && $3 != "Name") print $3 }' \
        | sort -u | write_list "$BACKUP_DIR/default.zypper.list.sh" zypperList
}

# Gems installed into the user's gem directory (which is where Gaudi puts them)
backup_gem() {
    local gems=""

    if ! gaudi::command_exists gem || ! gaudi::command_exists ruby; then
        gaudi::warn "Skipping gem backup: ruby and gem are not available"
        return 0
    fi

    # Read the gemspecs in the user directory directly: asking RubyGems for
    # "all specifications" also returns the gems that ship with Ruby itself.
    gems="$(ruby -e 'puts Dir[File.join(Gem.user_dir, "specifications", "*.gemspec")].map { |file| Gem::Specification.load(file) }.compact.map(&:name).uniq.sort' 2>/dev/null || true)"
    if [[ -z "$gems" ]]; then
        gaudi::log "No user-installed gems to back up"
        return 0
    fi

    printf "%s\n" "$gems" | write_list "$BACKUP_DIR/default.gem.list.sh" gemList
}

# Copy the files named in the templates' dotfiles.list (paths relative to the
# home directory, one per line) into <backup>/dotfiles, keeping their layout.
# A symlink is backed up as the file or directory it points to: the link
# itself would only mean something on this machine.
backup_dotfiles() {
    local list=""
    local entry=""
    local path=""
    local line_number=""
    local target=""
    local copied=0

    list="$(gaudi::dotfiles_lists | head -n 1)"
    if [[ -z "$list" ]]; then
        gaudi::log "No dotfiles.list in the templates: no dotfiles backed up"
        return 0
    fi

    # shellcheck disable=SC2034  # the line number is only needed by gaudi check
    while IFS=$'\t' read -r line_number entry; do
        if ! path="$(gaudi::dotfile_path "$entry")"; then
            gaudi::warn "Skipping '$entry' in $list: paths must be inside the home directory"
            continue
        fi
        entry="$path"
        if [[ ! -e "$HOME/$entry" ]]; then
            gaudi::warn "Skipping '$entry': not found in $HOME"
            continue
        fi
        # cp -H below follows a symlinked entry. A link to a directory is only
        # followed to somewhere inside the home directory, never to the home
        # directory itself or out of it.
        if [[ -L "$HOME/$entry" && -d "$HOME/$entry" ]]; then
            target="$(cd -P -- "$HOME/$entry" 2>/dev/null && pwd)" || target=""
            if [[ -z "$target" || "$target" != "$(cd -P -- "$HOME" && pwd)"/* ]]; then
                gaudi::warn "Skipping '$entry': it is a symlink to a directory outside the home directory"
                continue
            fi
        fi

        mkdir -p "$BACKUP_DIR/dotfiles/$(dirname "$entry")"
        rm -rf "$BACKUP_DIR/dotfiles/${entry:?}"
        if cp -RH "$HOME/$entry" "$BACKUP_DIR/dotfiles/$entry"; then
            copied=$((copied + 1))
        else
            gaudi::record_failure "copying $entry"
        fi
    done < <(gaudi::dotfiles_list_entries "$list")

    gaudi::success "Copied $copied dotfile(s) to $BACKUP_DIR/dotfiles"
}

gaudi::log "Writing backup to $BACKUP_DIR"

gaudi::detect_os
# The Brewfile, this operating system's own package manager (none on macOS),
# gems and dotfiles
default_managers="bundle $(gaudi::os_list_type) gem dotfiles"

for manager in ${GAUDI_BACKUP_MANAGERS:-$default_managers}; do
    case "$manager" in
        bundle|apt|dnf|pacman|zypper|gem|dotfiles)
            # Whatever else goes wrong in one manager must not stop the others
            "backup_$manager" || gaudi::record_failure "$manager backup"
            ;;
        brew|cask|tap|mas|npm|pip|go)
            gaudi::warn "'$manager' is now part of the Brewfile: use GAUDI_BACKUP_MANAGERS=bundle"
            ;;
        *)
            gaudi::warn "Unknown backup manager: $manager"
            ;;
    esac
done

if gaudi::report_failures; then
    gaudi::success "Backup complete"
else
    exit 1
fi
