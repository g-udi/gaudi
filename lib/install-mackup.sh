#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -d "$GAUDI_TEMPLATES_LOCATION/templates/mackup" && -f "$HOME"/.mackup.cfg ]]; then

_echo "

Keep your application settings in sync (OS X/Linux) with Mackup

${BLUE}What does it do${NC}

Back ups your application settings in a safe directory (e.g. Dropbox)
Syncs your application settings among all your workstations
Restores your configuration on any fresh install in one command line
By only tracking pure configuration files, it keeps the crap out of your freshly new installed workstation (no cache, temporary and locally specific files are transfered).

${YELLOW}Mackup makes setting up the environment easy and simple, saving time for your family, great ideas, and all the cool stuff you like. invoked with many directories as arguments, it does this for each directory listed.${NC}

"
    printf "We noticed you have mackup folder available. Would you like to run mackup backup?  "
    if [[ $(read_answer) =~ ^[yY]$ ]]; then
        if ! command_exists stow; then
            printf "\n\n%s\n" "We noticed that mackup is not installed on your machine .. Installing now ..."
            brew install mackup
        else
            printf "\n${RED}%s$GREEN %s ${NC}\n\n" "mackup is installed" "✓"
        fi
        mackup restore
    fi
fi;