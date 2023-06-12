#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

# Install software from a software list definition 
# e.g., installSoftwareList "brew install" "false" "${brewList[@]}"
#   <Function> command: The install command to execute on an install item
#   <Boolean> withPrompt: Indicate if we need to prompt the user to accept the installation of each item
#   <Array> softwareList: The software list reference
function installSoftwareList {
    echo ""
    installCommand=$1 && shift
    isWithPrompt=$1 && shift
    local softwareList=("$@")

    for item in "${softwareList[@]}"; do
        if [[ $installCommand = *"mas"* ]]; then
            software="${item%%::*}"
            listItem="${item#*::}"
        else
            listItem=$item
            software="${listItem%%::*}"
        fi
        softwareDescription="${listItem##*::}"
        if [[ $isWithPrompt = "true" ]]; then
            printf "\n%s${MAGENTA} %s\n${YELLOW}%s ${NC}%s${GREEN}%s${NC} " "👾 Installing" "$software" "Description:" "$softwareDescription" " | Would you like to install this? [Y/N] "
            read -r -n 1 REPLY
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${installCommand} "${software}"
            fi;
        else
            printf "\n%s${MAGENTA} %s\n${YELLOW}%s ${NC}%s\n" "👾 Installing" "$software" "Description:"  "$softwareDescription"
            ${installCommand} "${software}"
        fi
    done
}

# Install or update a brew recipe
# e.g., brew_install_or_upgrade recipe
#   <String> Recipe: The recipe name we wish to install or upgrade
function brew_install_or_upgrade {
  if _brew ls --versions "$1" >/dev/null; then
    if (_brew outdated | grep "$1" > /dev/null); then 
      echo "Upgrading already installed package $1 ..."
      _brew upgrade "$1"
    else 
      echo "Latest $1 is already installed"
    fi
  else
    _brew install "$1"
  fi
}

# Install or update a ruby gem
# e.g., gem_install_or_update gem
#   <String> Gem: The gem name we wish to install or upgrade
gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
  fi
}