#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2044,SC1090,SC2002,SC2125,SC1087,SC2154

GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"

printf "\n${YELLOW}%b${NC}" "Would you like to install all the recommended configs [Type N to select what you want to install one by one]? [Y/N] ";
if [[ $(read_answer) =~ ^[Yy]$ ]]; then
    for CONFIG in $(find "$GAUDI_TEMPLATES_LOCATION" -type f -iname "*.configs.osx.sh"); do
        . "$CONFIG"
        printf "%b\n" "${GREEN}${_info} ✅"
        _command
    done
else
    for CONFIG in $(find "$GAUDI_TEMPLATES_LOCATION" -type f -iname "*.configs.osx.sh"); do
        . "$CONFIG"
        printf "%b" "${GREEN}${_info} [Y/N] "
        if [[ $(read_answer) =~ ^[Yy]$ ]]; then
            _command
        fi
    done
fi

