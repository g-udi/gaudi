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
        find . -type f -iname `echo "pre.${listType}*.hooks.sh"` | while read PRE_HOOK; do
            . "${SOURCE_LOCATION}/$PRE_HOOK"
        done
            
        for LIST in $(find . -type f -iname `echo "*${listType}.list.sh"`); do
            listName=`cat "${SOURCE_LOCATION}/$LIST" | grep "# @List: "`
            if [[ $LIST = *"default"* ]]; then
                echo "\n🤖 Installing ${YELLOW}default ${listType}${NC} software list"
            else
                _listName=`cat "${SOURCE_LOCATION}/$LIST" | grep "# @Name:"`
                _listDescription=`cat "${SOURCE_LOCATION}/$LIST" | grep "# @Description:"`
                echo "\n🤖 Installing${YELLOW}${_listName#*:} ${listType}${NC} software list:${MAGENTA}${_listDescription#*:}${NC}"
            fi;
            
            read -p "Would you like to proceed ? [Y/N] " -n 1;
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                . "${SOURCE_LOCATION}/$LIST"
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
        find . -type f -iname `echo "post.${listType}*.hooks.sh"` | while read PRE_HOOK; do
            . "${SOURCE_LOCATION}/$PRE_HOOK"
        done
    fi

done