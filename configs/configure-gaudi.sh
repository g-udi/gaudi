#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"

_clone-gaudi-templates() {
    echo -e "\nEnter the url of gaudi templates (e.g., https://github.com/g-udi/gaudi-templates):"
    read -r GAUDI_TEMPLATE_URL
    git clone "$GAUDI_TEMPLATE_URL" "$GAUDI_TEMPLATES_LOCATION"
}

if [[ -d $GAUDI_TEMPLATES_LOCATION ]]; then
    read -rp "Gaudi templates already exist in $GAUDI_TEMPLATES_LOCATION. Overwrite? [Y/N] " REPLY
    [[ $REPLY =~ ^[yY]$ ]] && rm -rf "$GAUDI_TEMPLATES_LOCATION" && _clone-gaudi-templates
else
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
    _clone-gaudi-templates
fi

export GAUDI_TEMPLATES_LOCATION