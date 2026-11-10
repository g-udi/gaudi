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
mkdir -p "$BACKUP_DIR"

# One Brewfile covers taps, formulae, casks, Mac App Store apps, VS Code
# extensions and the npm/go/cargo/uv packages Homebrew knows how to track.
backup_bundle() {
    local file="$BACKUP_DIR/Brewfile"

    if ! gaudi::command_exists brew; then
        gaudi::warn "Skipping Brewfile backup: Homebrew is not installed"
        return 0
    fi

    brew bundle dump --describe --force "--file=$file" \
        || gaudi::record_failure "brew bundle dump"
    [[ -f "$file" ]] && gaudi::success "Wrote $file"
    return 0
}

# Only packages the user asked for, not the whole base system
backup_apt() {
    local file="$BACKUP_DIR/default.apt.list.sh"
    local package_name=""

    if ! gaudi::command_exists apt-mark; then
        gaudi::warn "Skipping apt backup: apt-mark is not available"
        return 0
    fi

    {
        printf "# @Name: Default\n# @List: aptList\naptList=(\n"
        while IFS= read -r package_name; do
            [[ -n "$package_name" ]] || continue
            printf '  "%s"\n' "$package_name"
        done < <(apt-mark showmanual 2>/dev/null | sort)
        printf ")\n"
    } > "$file"
    gaudi::success "Wrote $file"
}

gaudi::log "Writing backup to $BACKUP_DIR"

get_os
default_managers="bundle"
[[ "${OS:-}" == "debian" ]] && default_managers="bundle apt"

for manager in ${GAUDI_BACKUP_MANAGERS:-$default_managers}; do
    case "$manager" in
        bundle|apt)
            "backup_$manager"
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
