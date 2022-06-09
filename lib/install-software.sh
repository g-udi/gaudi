#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2044,SC1090,SC2002,SC2125,SC1087

softwareLists=(
    "debian|apt-get::sudo apt-get -y --force-yes install"
    "*|brew::brew_install_or_upgrade"
    "osx|mas::mas install"
    "osx|cask::brew install --cask"
    "*|npm::npm install -g"
    "*|pip::pip3 install --upgrade --user --ignore-installed six"
    "*|go::go get"
    "*|gem::gem_install_or_update install"
)

for item in "${softwareLists[@]}"; do
    
    operatingSystem="${item%%|*}"
    list="${item%%::*}"
    listType="${list#*|}"
    listCommand="${item#*::}"
    
    if [[ $operatingSystem = "$OS" || $operatingSystem = "*" ]]; then

        # We need now to check if we need to run any pre hooks
        find "$GAUDI" -type f -iname "pre.${listType}*.hooks.sh" | while read -r PRE_HOOK; do
            . "$PRE_HOOK"
        done

        for LIST in $(find "$GAUDI" -type f -iname "*${listType}.list.sh"); do
            listName=$(cat "$LIST" | grep "# @List: ")
            if [[ $LIST = *"default"* ]]; then
                printf "\n%b\n" "🤖 Installing ${YELLOW}default ${listType}${NC} software list"
            else
                _listName=$(cat "$LIST" | grep "# @Name:")
                _listDescription=$(cat "$LIST" | grep "# @Description:")
                printf "\n%b\n" "🤖 Installing${YELLOW}${_listName#*:} ${listType}${NC} software list:${MAGENTA}${_listDescription#*:}${NC}"
            fi;

            read -rp "Would you like to proceed ? [Y/N] " -n 1;
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                . "$LIST"
                referencedList=$(echo "${listName#*:}" | xargs)
                __list=$referencedList[@]
                read -rp "Would you like to install all the recommended software [Type N to select what you want to install one by one]? [Y/N] " -n 1;
                echo "";
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    installSoftwareList "$listCommand" "false" "${!__list}"
                else
                    installSoftwareList "$listCommand" "true" "${!__list}"
                fi
            fi
        done;

        # We need now to check if we need to run any post hooks
        find "$GAUDI" -type f -iname "post.${listType}*.hooks.sh" | while read -r POST_HOOK; do
            . "$POST_HOOK"
        done
    fi

done
