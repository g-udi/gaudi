#!/usr/bin/env bash

echo -e "🔬 All brew formulas installed .. setting up few things"

# Check if we have asdf plugins and languages to set
for PLUGINS_LIST in $(find . -type f -iname asdf-plugins.list.sh); do
    echo -e "Installing ${YELLOW}programming languages${NC} ${MAGENTA}plugins${NC} using asdf 🔮"
    . "${SOURCE_LOCATION}/$PLUGINS_LIST"
    for plugin in ${asdfPluginsList[@]}; do
        echo -e "Adding asdf ${MAGENTA}plugin${NC} ${RED}$plugin${NC}"
        asdf plugin-add $plugin
    done
done;

# Import the Node.js release team's OpenPGP keys to main keyring
echo -e "Import the Node.js release team's OpenPGP keys to main keyring 🔑"
#bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring > /dev/null 2>&1

read -p "Would you like to install the programming languages set? [Y/N] " -n 1 </dev/tty
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for LANGUAGES_LIST in $(find . -type f -iname asdf-languages.list.sh); do
        echo -e "\nInstalling ${YELLOW}programming languages${NC} using asdf 🔮"
        . "${SOURCE_LOCATION}/$LANGUAGES_LIST"
        read -p "Would you like to install all the programming languages set [Type N to select what you want to install one by one]? [Y/N] " -n 1 SELECT_ALL </dev/tty
        
        for language in "${asdfLanguagesList[@]}"; do
            _language="${language%%::*}"
            _description="${language##*::}"            
            if [[ $SELECT_ALL =~ ^[nN]$ ]]; then
                echo -e ""
                read -p "👾 $(echo -e "${MAGENTA}$_language${NC}\n${YELLOW}Description:${NC} $_description") | Would you like to install this? [Y/N] " -n 1 LANGUAGE_CONFIRM </dev/tty
                echo -e ""
                if [[ $LANGUAGE_CONFIRM =~ ^[Yy]$ ]]; then
                    asdf install ${_language} && setGlobal ${_language}
                fi;
            else
                asdf install ${_language} && setGlobal ${_language}
            fi

            setGlobal() {
                read -p "Would you like to set ${1} ${2} as the global version 🌍 ? [Y/N] " -n 1 is_GLOBAL </dev/tty   
                if [[ $is_GLOBAL =~ ^[Yy]$ ]]; then
                    asdf global ${1} ${2}
                fi;  
            }

        done;
    done;
fi

echo -e ""
# Check if we have any default gems or npm modules
for GEMS in $(find $SOURCE_LOCATION -type f -iname .default-gems); do
    echo -e "Found a .default-gems 💎 file .. moving it to 🏠"
    cp $GEMS ~
done;

# Check if we have any default gems or npm modules
for NPMS in $(find $SOURCE_LOCATION -type f -iname .default-npm-packages); do
    echo -e "Found a .default-npm-packages 📦 file .. moving it to 🏠"
    cp $NPMS ~
done;