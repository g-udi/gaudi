#!/usr/bin/env bash
# shellcheck shell=bash

echo ""

if [ -d "$GAUDI_TEMPLATES_LOCATION/templates/extras" ]; then
    printf  "We noticed you have scripts in the 'extras' folder. Would you like to run them?  "
    if [[ $(read_answer) =~ ^[yY]$ ]]; then
        for shfile in "$GAUDI_TEMPLATES_LOCATION"/templates/extras/*.sh
        do
            chmod +x "$shfile"
            $shfile
        done
    fi
fi;
