#!/usr/bin/env bash
# shellcheck shell=bash

# Restore the files under <templates>/dotfiles into the home directory, keeping
# their layout. A file that is already identical is left alone; a different
# one is moved aside (<file>.gaudi-backup) before the new one is copied.

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"
gaudi_dotfiles_dir="$GAUDI_TEMPLATES_LOCATION/dotfiles"

[[ -d "$gaudi_dotfiles_dir" ]] || return 0

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
    gaudi_dotfile_target="$HOME/${gaudi_dotfile#"$gaudi_dotfiles_dir"/}"
    if gaudi::dotfile_differs "$gaudi_dotfile" "$gaudi_dotfile_target"; then
        gaudi_dotfiles_changed=$((gaudi_dotfiles_changed + 1))
        if [[ -e "$gaudi_dotfile_target" ]]; then
            printf "  %s (replaces the existing file)\n" "$gaudi_dotfile_target"
        else
            printf "  %s (new)\n" "$gaudi_dotfile_target"
        fi
    fi
done < <(find "$gaudi_dotfiles_dir" -type f -print | sort)

if [[ "$gaudi_dotfiles_changed" -eq 0 ]]; then
    gaudi::success "Dotfiles are already in place"
    return 0
fi

gaudi::confirm "Restore these $gaudi_dotfiles_changed dotfile(s) into $HOME?" "n" || return 0

while IFS= read -r gaudi_dotfile; do
    [[ -n "$gaudi_dotfile" ]] || continue
    gaudi_dotfile_target="$HOME/${gaudi_dotfile#"$gaudi_dotfiles_dir"/}"
    gaudi::dotfile_differs "$gaudi_dotfile" "$gaudi_dotfile_target" || continue
    gaudi::restore_dotfile "$gaudi_dotfile" "$gaudi_dotfile_target" \
        || gaudi::record_failure "dotfile $gaudi_dotfile_target"
done < <(find "$gaudi_dotfiles_dir" -type f -print | sort)
