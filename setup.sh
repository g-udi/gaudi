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

# # Install prerequisites
. "${SOURCE_LOCATION}/bin/${OS}/install-pre-requisits.sh"

# # Run the SSH configurations
. "${SOURCE_LOCATION}/configs/configure-gaudi.sh"

# # Configure shell helpers
. "${SOURCE_LOCATION}/bin/install-shell-helpers.sh"

# # Install software from lists
. "${SOURCE_LOCATION}/bin/install-software.sh"

# # Install dotfiles
. "${SOURCE_LOCATION}/bin/install-dotfiles.sh"

# Install extras
. "${SOURCE_LOCATION}/bin/install-extras.sh"

printf "Good Bye"
