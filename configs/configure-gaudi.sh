#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_TEMPLATES_LOCATION="${GAUDI_TEMPLATES_LOCATION:-${GAUDI:-$HOME/.gaudi}/templates}"
GAUDI_DEFAULT_TEMPLATES_URL="${GAUDI_DEFAULT_TEMPLATES_URL:-https://github.com/g-udi/gaudi-templates.git}"

gaudi::clone_templates() {
    local template_url="$1"

    mkdir -p "$(dirname "$GAUDI_TEMPLATES_LOCATION")"
    git clone "$template_url" "$GAUDI_TEMPLATES_LOCATION"
}

if [[ -d "$GAUDI_TEMPLATES_LOCATION/.git" ]]; then
    if gaudi::confirm "Update existing templates at $GAUDI_TEMPLATES_LOCATION?" "y"; then
        git -C "$GAUDI_TEMPLATES_LOCATION" pull --ff-only
    fi
elif [[ -e "$GAUDI_TEMPLATES_LOCATION" && -n "$(find "$GAUDI_TEMPLATES_LOCATION" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    gaudi::warn "Using existing non-Git templates directory: $GAUDI_TEMPLATES_LOCATION"
else
    printf "Enter the Gaudi templates Git URL [%s]: " "$GAUDI_DEFAULT_TEMPLATES_URL"
    template_url="$(read_git_url "$GAUDI_DEFAULT_TEMPLATES_URL")"
    rm -rf "$GAUDI_TEMPLATES_LOCATION"
    gaudi::clone_templates "$template_url"
fi

export GAUDI_TEMPLATES_LOCATION
