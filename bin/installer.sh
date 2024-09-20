#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154


# @function installSoftwareList
# @description Install software from a software list definition
# @param <Function> command: The install command to execute on an install item
# @param <Boolean> withPrompt: Indicate if we need to prompt the user to accept the installation of each item
# @param <Array> softwareList: The software list reference
# @example installSoftwareList "brew install" "false" "${brewList[@]}"
function installSoftwareList {
    local installCommand=$1 isWithPrompt=$2
    shift 2
    local softwareList=("$@")

    for item in "${softwareList[@]}"; do
        local software softwareDescription
        if [[ $installCommand == *"mas"* ]]; then
            software="${item%%::*}"
            softwareDescription="${item#*::}"
        else
            software="${item%%::*}"
            softwareDescription="${item##*::}"
        fi

        printf "\n%s${MAGENTA} %s\n${YELLOW}%s ${NC}%s" "👾 Installing" "$software" "Description:" "$softwareDescription"
        
        if [[ $isWithPrompt == "true" ]]; then
            printf "${GREEN}%s${NC}" " | Would you like to install this? [Y/N] "
            read -r -n 1 REPLY
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && ${installCommand} "${software}"
        else
            echo
            ${installCommand} "${software}"
        fi
    done
}

# @function brew_install_or_upgrade
# @description Install or update a brew recipe
# @param <String> Recipe: The recipe name we wish to install or upgrade
function brew_install_or_upgrade {
  if brew ls --versions "$1" >/dev/null; then
    if (brew outdated | grep "$1" > /dev/null); then 
      echo "Upgrading already installed package $1 ..."
      brew upgrade "$1"
    else 
      echo "Latest $1 is already installed"
    fi
  else
    brew install "$1"
  fi
}

# @function gem_install_or_update
# @description Install or update a ruby gem
# @param <String> Gem: The gem name we wish to install or upgrade
function gem_install_or_update {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@" --user-install
  fi
}