#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/colors.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/helpers.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/commands.sh"

BACKUP_DIR="${1:-$PWD/backup}"
GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$SOURCE_LOCATION}/templates}"
mkdir -p "$BACKUP_DIR"

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
backup_dotfiles() {
    local list=""
    local entry=""
    local path=""
    local copied=0

    [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] && list="$(find "$GAUDI_TEMPLATES_LOCATION" -type f -name "dotfiles.list" -print | sort | head -n 1)"
    if [[ -z "$list" ]]; then
        gaudi::log "No dotfiles.list in the templates: no dotfiles backed up"
        return 0
    fi

    while IFS= read -r entry || [[ -n "$entry" ]]; do
        entry="${entry%%#*}"
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        [[ -n "$entry" ]] || continue

        if ! path="$(gaudi::dotfile_path "$entry")"; then
            gaudi::warn "Skipping '$entry' in $list: paths must be inside the home directory"
            continue
        fi
        entry="$path"
        if [[ ! -e "$HOME/$entry" ]]; then
            gaudi::warn "Skipping '$entry': not found in $HOME"
            continue
        fi

        mkdir -p "$BACKUP_DIR/dotfiles/$(dirname "$entry")"
        rm -rf "$BACKUP_DIR/dotfiles/${entry:?}"
        cp -R "$HOME/$entry" "$BACKUP_DIR/dotfiles/$entry" || gaudi::record_failure "copying $entry"
        copied=$((copied + 1))
    done < "$list"

    gaudi::success "Copied $copied dotfile(s) to $BACKUP_DIR/dotfiles"
}

gaudi::log "Writing backup to $BACKUP_DIR"

get_os
default_managers="bundle gem dotfiles"
[[ "${OS:-}" == "debian" ]] && default_managers="bundle apt gem dotfiles"
[[ "${OS:-}" == "fedora" ]] && default_managers="bundle dnf gem dotfiles"
[[ "${OS:-}" == "arch" ]] && default_managers="bundle pacman gem dotfiles"
[[ "${OS:-}" == "opensuse" ]] && default_managers="bundle zypper gem dotfiles"

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
