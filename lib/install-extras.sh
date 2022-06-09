#!/usr/bin/env bash
# shellcheck shell=bash

echo ""

if [ -d "$GAUDI/templates/extras" ]; then
    printf  "We noticed you have scripts in the 'extras' folder. Would you like to run them?  "
    read -re REPLY
    if [[ $REPLY =~ ^[yY]$ ]]; then
        for shfile in "$GAUDI"/templates/extras/*.sh
        do
            chmod +x "$shfile"
            $shfile
        done
    fi
fi;
