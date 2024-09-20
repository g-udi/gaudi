#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2044,SC1090,SC2002,SC2125,SC1087,SC2154

GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"

printf "\n${YELLOW}%b${NC}" "Would you like to install all the recommended configs? [Type N to select what you want to install one by one] [Y/N] ";
read -r all_configs

for CONFIG in "$GAUDI_TEMPLATES_LOCATION"/*.configs.osx.sh; do
    . "$CONFIG"
    if [[ $all_configs =~ ^[Yy]$ ]]; then
        printf "%b\n" "${GREEN}${_info} ✅"
        _command
    else
        printf "%b" "${GREEN}${_info} [Y/N] "
        read -r install_config
        [[ $install_config =~ ^[Yy]$ ]] && _command
    fi
done

