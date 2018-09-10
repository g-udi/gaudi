#!/usr/bin/env bash

softwareLists=(
    "debian|apt-get::sudo apt-get -y --force-yes install"
    "*|brew::brew install"
    "osx|mas::mas install"
    "osx|cask::brew cask install"
    "*|npm::npm install -g"
    "*|pip::pip3 install --upgrade --user --ignore-installed six"
    "*|go::go get"
    "*|gem::gem install"
)

for item in "${softwareLists[@]}"; do
    
    operatingSystem="${item%%|*}"
    list="${item%%::*}"
    listType="${list#*|}"
    listCommand="${item#*::}"

    if [[ $operatingSystem = ${OS} || $operatingSystem = "*" ]]; then
        # We need now to check if we need to run any pre hooks
        find $SOURCE_LOCATION -type f -iname `echo "pre.${listType}*.hooks.sh"` | while read PRE_HOOK; do
            . $PRE_HOOK
        done
            
        for LIST in $(find $SOURCE_LOCATION -type f -iname `echo "*${listType}.list.sh"`); do
            listName=`cat "$LIST" | grep "# @List: "`
            if [[ $LIST = *"default"* ]]; then
                printf "\n🤖 Installing ${YELLOW}default ${listType}${NC} software list\n"
            else
                _listName=`cat "$LIST" | grep "# @Name:"`
                _listDescription=`cat "$LIST" | grep "# @Description:"`
                printf "\n🤖 Installing${YELLOW}${_listName#*:} ${listType}${NC} software list:${MAGENTA}${_listDescription#*:}${NC}\n"
            fi;
            
            read -p "Would you like to proceed ? [Y/N] " -n 1;
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                . $LIST
                referencedList=`echo "${listName#*:}" | xargs`
                __list=$referencedList[@]
                read -p "Would you like to install all the recommended software [Type N to select what you want to install one by one]? [Y/N] " -n 1;
                echo "";
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    installSoftwareList "$listCommand" "false" "${!__list}"
                else
                    installSoftwareList "$listCommand" "true" "${!__list}"
                fi
            fi
        done;

        # We need now to check if we need to run any post hooks
        find $SOURCE_LOCATION -type f -iname `echo "post.${listType}*.hooks.sh"` | while read PRE_HOOK; do
            . $PRE_HOOK
        done
    fi

done