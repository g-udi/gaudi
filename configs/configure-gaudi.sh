#!/usr/bin/env bash
# shellcheck shell=bash

declare GAUDI_DEFAULT_TEMPLATES GAUDI_TEMPLATES_LOCATION

GAUDI_DEFAULT_TEMPLATES="git@github.com:g-udi/gaudi-templates"
GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"

echo -e "The next step will prompt you for the url of gaudi templates (lists, hooks, templates, etc.)...

${YELLOW}[D,d]${NC} will install g-udi's default templates from: ${MAGENTA} $GAUDI_DEFAULT_TEMPLATES

${YELLOW}If you want to point to any other location then just type the github url of that repo${NC}
"

read -rp ">> " GAUDI_TEMPLATE_URL </dev/tty;
echo ""

if [[ $GAUDI_TEMPLATE_URL =~ ^[dD]$ ]]; then
    GAUDI_TEMPLATE_URL=$GAUDI_DEFAULT_TEMPLATES
fi;

if [[ -d $GAUDI_TEMPLATES_LOCATION ]]; then
    printf "${RED}%s${NC}\n\n" "We noticed that there already gaudi templates in $GAUDI_TEMPLATES_LOCATION"
    read -rp "Would you like to overwrite those? [Y/N] " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$GAUDI_TEMPLATES_LOCATION"
        git clone $GAUDI_TEMPLATE_URL "$GAUDI_TEMPLATES_LOCATION"
    fi;
else
    mkdir "${HOME}/.gaudi/templates"
    git clone $GAUDI_TEMPLATE_URL "$GAUDI_TEMPLATES_LOCATION"
fi

