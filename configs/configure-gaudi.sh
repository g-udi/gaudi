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
        git -C "$GAUDI_TEMPLATES_LOCATION" pull --ff-only \
            || gaudi::warn "Could not update templates (local changes or no network): using them as they are"
    fi
elif [[ -e "$GAUDI_TEMPLATES_LOCATION" && -n "$(find "$GAUDI_TEMPLATES_LOCATION" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    gaudi::warn "Using existing non-Git templates directory: $GAUDI_TEMPLATES_LOCATION"
else
    if [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]]; then
        gaudi::log "Templates: $GAUDI_DEFAULT_TEMPLATES_URL"
    else
        printf "Enter the Gaudi templates Git URL [%s]: " "$GAUDI_DEFAULT_TEMPLATES_URL"
    fi
    if template_url="$(gaudi::read_git_url "$GAUDI_DEFAULT_TEMPLATES_URL")"; then
        # Only an empty directory can be here (see the branch above)
        [[ -d "$GAUDI_TEMPLATES_LOCATION" ]] && rmdir "$GAUDI_TEMPLATES_LOCATION"
        gaudi::clone_templates "$template_url" || gaudi::record_failure "cloning templates from $template_url"
    else
        gaudi::record_failure "templates: no reachable repository, software and config steps will be skipped"
    fi
fi

export GAUDI_TEMPLATES_LOCATION
