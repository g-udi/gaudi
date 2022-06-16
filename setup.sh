#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,1091

declare SOURCE_LOCATION 

SOURCE_LOCATION="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

export SOURCE_LOCATION

# Load the external configurations
source "$SOURCE_LOCATION/bin/colors.sh"
source "$SOURCE_LOCATION/bin/configs.sh"
source "$SOURCE_LOCATION/bin/installer.sh"

_echo "
\033c

   ▄██████▄     ▄████████ ███    █▄  ████████▄   ▄█  
  ███    ███   ███    ███ ███    ███ ███   ▀███ ███  
  ███    █▀    ███    ███ ███    ███ ███    ███ ███▌ 
 ▄███          ███    ███ ███    ███ ███    ███ ███▌ 
▀▀███ ████▄  ▀███████████ ███    ███ ███    ███ ███▌ 
  ███    ███   ███    ███ ███    ███ ███    ███ ███  
  ███    ███   ███    ███ ███    ███ ███   ▄███ ███  
  ████████▀    ███    █▀  ████████▀  ████████▀  █▀   

${WHITE}Greetings $(whoami) .....${NC}\n

Gaudi is a tool that allows you to install a set of predefined software lists! 
Please make sure to follow the instructions carefully to avoid any uneeded installations.

The Following script will set up your machine based on the various configurations specified in the config files\n
"

# Get the operating system and have it in the global exportable variable
get_os
get_shell_type

[[ $GAUDI_SHELL != "bash" ]] && printf "\n$RED%s$NC\n" "gaudi requires bash as your interactive shell! please adjust accordingly and re-run the setup" && exit

# Install prerequisites
source "${SOURCE_LOCATION}/lib/${OS}/install-pre-requisits.sh"

# Run the ssh configurations
source "${SOURCE_LOCATION}/configs/configure-ssh.sh"

# Run the gaudi configurations
source "${SOURCE_LOCATION}/configs/configure-gaudi.sh"

# Configure shell helpers
source "${SOURCE_LOCATION}/lib/install-shell-helpers.sh"

# Install Software
source "${SOURCE_LOCATION}/lib/install-software.sh"

# Install dotfiles
source "${SOURCE_LOCATION}/lib/install-dotfiles.sh"

# Install mackup
source "${SOURCE_LOCATION}/lib/install-mackup.sh"

# Install extras
source "${SOURCE_LOCATION}/lib/install-extras.sh"

_echo "Setting up your machine with gaudi is finished! Enjoy"