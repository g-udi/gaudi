#!/usr/bin/env bash

read -p "Would you like to install the programming languages set usign asdf? [Y/N] " -n 1 </dev/tty
if [[ $REPLY =~ ^[Yy]$ ]]; then

    # Check if we have asdf plugins and languages to set
    for PLUGINS_LIST in $(find . -type f -iname asdf-plugins.list.sh); do
        printf "Installing ${YELLOW}programming languages${NC} ${MAGENTA}plugins${NC} using asdf 🔮"
        . $PLUGINS_LIST
        for plugin in ${asdfPluginsList[@]}; do
            printf "Adding asdf ${MAGENTA}plugin${NC} ${RED}$plugin${NC}\n"
            asdf plugin-add $plugin
        done
    done;

    # Import the Node.js release team's OpenPGP keys to main keyring
    printf "\nImport the Node.js release team's OpenPGP keys to main keyring 🔑\n"
    bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring > /dev/null 2>&1

    for LANGUAGES_LIST in $(find . -type f -iname asdf-languages.list.sh); do
        printf "\nInstalling ${YELLOW}programming languages${NC} using asdf 🔮\n"
        . "${SOURCE_LOCATION}/$LANGUAGES_LIST"
        read -p "Would you like to install all the programming languages set [Type N to select what you want to install one by one]? [Y/N] " -n 1 SELECT_ALL </dev/tty
        
        for language in "${asdfLanguagesList[@]}"; do
            _language="${language%%::*}"
            _description="${language##*::}"            
            if [[ $SELECT_ALL =~ ^[nN]$ ]]; then
                echo ""
                read -p "👾 $(printf "${MAGENTA}$_language${NC}\n${YELLOW}Description:${NC} $_description") | Would you like to install this? [Y/N] " -n 1 LANGUAGE_CONFIRM </dev/tty
                echo ""
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

    echo ""
    # Check if we have any default gems or npm modules
    for GEMS in $(find $SOURCE_LOCATION -type f -iname .default-gems); do
        echo "Found a .default-gems 💎 file .. moving it to 🏠"
        cp $GEMS ~
    done;

    # Check if we have any default gems or npm modules
    for NPMS in $(find $SOURCE_LOCATION -type f -iname .default-npm-packages); do
        echo "Found a .default-npm-packages 📦 file .. moving it to 🏠"
        cp $NPMS ~
    done;

    if [[ ! -d "${HOME}/.bash_it" ]] || [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
        printf "${YELLOW}%s$NC\n" "After the installation is done .. you need to configure asdf as follows:"
        printf "${RED}%s${NC}\n" "Depending on your OS and shell, run the following:"
        printf "\n%s ${MAGENTA}%s${NC}" "Bash on" "Ubuntu (and other Linux distros)"
        printf "\n\t%s" "echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc"
        printf "\n\t%s" "echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc"
        
        printf "\n\n%s ${MAGENTA}%s${NC}" "Bash on" "macOS"
        printf "\n\t%s" "echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bash_profile"
        printf "\n\t%s" "echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bash_profile"

        echo ""
        echo "Check the main asdf repo: https://github.com/asdf-vm/asdf for further configurations"
    else
        printf "Detected bash-it to be installed .. Trying to enable asdf pluings:\n"
        . "${HOME}/.bash_it/lib/composure.bash"
        cite _about _param _example _group _author _version
        . "${HOME}/.bash_it/lib/helpers.bash"
        _enable-plugin asdf
        _enable-completion asdf
    fi;
    
fi