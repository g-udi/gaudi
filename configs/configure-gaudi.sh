#!/usr/bin/env bash
# shellcheck shell=bash

declare GAUDI_TEMPLATES_LOCATION

GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"

function _clone-gaudi-templates {

    _echo "
The next step will prompt you for the url of gaudi templates (lists, hooks, templates, etc.)...

${MAGENTA}Example templates can be found at https://github.com/g-udi/gaudi-templates${NC}

${YELLOW}Please enter the url of the templates git repo${NC}
"

    printf ">> "
    GAUDI_TEMPLATE_URL=$(read_git_url);
    git clone "$GAUDI_TEMPLATE_URL" "$GAUDI_TEMPLATES_LOCATION"

}

if [[ -d $GAUDI_TEMPLATES_LOCATION ]]; then
    printf "${RED}%s${NC}\n\n%s" "We noticed that there already gaudi templates in $GAUDI_TEMPLATES_LOCATION" "Would you like to overwrite those? [Y/N] "
    if [[ $(read_answer) =~ ^[yY]$ ]]; then
        rm -rf "$GAUDI_TEMPLATES_LOCATION"
        _clone-gaudi-templates
    fi;
else
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
    _clone-gaudi-templates
fi


export GAUDI_TEMPLATES_LOCATION