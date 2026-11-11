#!/usr/bin/env bash
# shellcheck shell=bash

# Restore the files under <templates>/dotfiles into the home directory, keeping
# their layout. A file that is already identical is left alone; a different
# one is moved aside (<file>.gaudi-backup) before the new one is copied.
# A symlink to a file is restored as a copy of that file.

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"
gaudi_dotfiles_dir="$GAUDI_TEMPLATES_LOCATION/dotfiles"

[[ -d "$gaudi_dotfiles_dir" ]] || return 0

# Every file to restore. Symlinks that lead to a file count (cp follows them);
# one that leads to a directory or nowhere is reported and left out.
gaudi::dotfiles_to_restore() {
    local found=""

    while IFS= read -r found; do
        [[ -n "$found" ]] || continue
        if [[ -f "$found" ]]; then
            printf "%s\n" "$found"
        else
            gaudi::warn "Skipping $found: a symlink is only restored when it points to a file"
        fi
    done < <(find "$gaudi_dotfiles_dir" \( -type f -o -type l \) -print | sort)
}

gaudi::dotfile_differs() {
    [[ -f "$2" ]] || return 0
    if gaudi::command_exists cmp; then
        ! cmp -s "$1" "$2"
    else
        # Minimal images (Fedora) do not ship cmp
        [[ "$(cat "$1")" != "$(cat "$2")" ]]
    fi
}

gaudi::restore_dotfile() {
    local source_file="$1"
    local target="$2"
    local aside="$target.gaudi-backup"

    if [[ "${GAUDI_DRY_RUN:-false}" == "true" ]]; then
        printf "DRY RUN: dotfile %s\n" "$target"
        return 0
    fi

    mkdir -p "$(dirname "$target")" || return 1
    if [[ -e "$target" || -L "$target" ]]; then
        [[ -e "$aside" ]] && aside="$aside.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$aside" || return 1
        gaudi::log "Kept the previous $target as $aside"
    fi
    cp -p "$source_file" "$target"
}

gaudi_dotfiles_changed=0
while IFS= read -r gaudi_dotfile; do
    [[ -n "$gaudi_dotfile" ]] || continue
    if ! gaudi_dotfile_path="$(gaudi::dotfile_path "${gaudi_dotfile#"$gaudi_dotfiles_dir"/}")"; then
        gaudi::warn "Skipping $gaudi_dotfile: it would not be restored inside the home directory"
        continue
    fi
    gaudi_dotfile_target="$HOME/$gaudi_dotfile_path"
    if gaudi::dotfile_differs "$gaudi_dotfile" "$gaudi_dotfile_target"; then
        gaudi_dotfiles_changed=$((gaudi_dotfiles_changed + 1))
        if [[ -e "$gaudi_dotfile_target" ]]; then
            printf "  %s (replaces the existing file)\n" "$gaudi_dotfile_target"
        else
            printf "  %s (new)\n" "$gaudi_dotfile_target"
        fi
    fi
done < <(gaudi::dotfiles_to_restore)

if [[ "$gaudi_dotfiles_changed" -eq 0 ]]; then
    gaudi::success "Dotfiles are already in place"
    return 0
fi

gaudi::confirm "Restore these $gaudi_dotfiles_changed dotfile(s) into $HOME?" "n" || return 0

while IFS= read -r gaudi_dotfile; do
    [[ -n "$gaudi_dotfile" ]] || continue
    gaudi_dotfile_path="$(gaudi::dotfile_path "${gaudi_dotfile#"$gaudi_dotfiles_dir"/}")" || continue
    gaudi_dotfile_target="$HOME/$gaudi_dotfile_path"
    gaudi::dotfile_differs "$gaudi_dotfile" "$gaudi_dotfile_target" || continue
    gaudi::restore_dotfile "$gaudi_dotfile" "$gaudi_dotfile_target" \
        || gaudi::record_failure "dotfile $gaudi_dotfile_target"
done < <(gaudi::dotfiles_to_restore 2>/dev/null)
