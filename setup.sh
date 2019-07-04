#!/usr/bin/env bash

# The source directory and target directories | Contains the files and directories I want to work with.
if [ ! -n "$GAUDI" ]; then
    export SOURCE_LOCATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
else
    export SOURCE_LOCATION=~/.gaudi
fi

# Load the external configurations
source "$SOURCE_LOCATION/lib/configs.sh"

# Get the operating system and have it in the global exportable variable
getOperatingSystem

printf "
${WHITE}Greetings $USER .....${NC}\n
The Following script will set up your machine based on the various configurations specific in the config files\n
Before moving forward, we need your email address for various steps in the configuration process ...\n"

# Prompt and save the email address for the user
printf "Please enter your ${RED}email address${NC} (it will be used to configure SSH and any other needed configs):" && read EMAIL
# Export the email to make it accessible through the installation and configuration scripts
if [[ $EMAIL =~ $EMAIL_REGEX ]] ; then
    export EMAIL
else
    printf "\n\n${RED}You did not enter a valid email .. cannot move forward :(${NC}\n\n"
    exit
fi

# Configure shell helpers
. "${SOURCE_LOCATION}/bin/install-shell-helpers.sh"
# # Run the SSH configurations
# . "${SOURCE_LOCATION}/configs/lib/configure-ssh.sh"

. "${SOURCE_LOCATION}/bin/install-software.sh"

# Prompt user to select his type of shell
printf "Please select what ${RED}shell${NC} you need to install ${MAGENTA}(or have already installed)${NC} between ${YELLOW}bash${NC} and ${YELLOW}zsh${NC}: " && read SHELL_TYPE
export SHELL_TYPE

# Install prerequisites
. "${SOURCE_LOCATION}/bin/${OS}/install-pre-requisits.sh"
# Configure shell helpers
. "${SOURCE_LOCATION}/bin/install-shell-helpers.sh"
# Install recommended software kit
. "${SOURCE_LOCATION}/configs/repositories-setup.sh"
# Configure the custom beamery lib
. "${SOURCE_LOCATION}/configs/configure-beamery-plugins.sh"
# Run the text editors configurations
. "${SOURCE_LOCATION}/configs/configure-editors.sh"
# Run the text editors configurations
. "${SOURCE_LOCATION}/configs/configure-templates.sh"
# Cleanup
. "${SOURCE_LOCATION}/bin/${OS}/cleanup.sh"

printf "


To configure SSH login without password please do the following on your local machine:

        ${YELLOW}cat ~/.ssh/id_rsa.pub | ssh root@[IP_ADDRESS] \"mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys${NC}\"

        You also need to configure the git config file with:
        Host [IP_ADDRESS]
        User root
        IdentityFile ~/.ssh/id_rsa
        PubkeyAuthentication yes
        PreferredAuthentications publickey

The script will reload now the shell .. do not forget afterwards to make sure that you have node installed if you used ${RED}NVM${NC} by running:
${YELLOW}nvm install 4.4.7${NC}

If you have also installed ${YELLOW}bash-it${NC}You will also need to enable ${MAGENTA}Beamery plugins${NC} by executing:
bash-it enable plugin beamery
bash-it enable alias beamery
bash-it enable completion beamery
"

archey -c -o

if [[ "$OS" == "linux" ]]; then
    source "${HOME}/.bashrc"
elif [[ "$OS" == "osx" ]]; then
    source "${HOME}/.bash_profile"
fi
