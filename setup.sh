#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,1091

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &> /dev/null && pwd 2> /dev/null)"
export SOURCE_LOCATION

# Load external configurations
for config in "$SOURCE_LOCATION"/bin/{colors,commands,helpers,installer}.sh; do
    source "$config"
done

printf "\033c"

cat << EOF

   ▄██████▄     ▄████████ ███    █▄  ████████▄   ▄█  
  ███    ███   ███    ███ ███    ███ ███   ▀███ ███  
  ███    █▀    ███    ███ ███    ███ ███    ███ ███▌ 
 ▄███          ███    ███ ███    ███ ███    ███ ███▌ 
▀▀███ ████▄  ▀███████████ ███    ███ ███    ███ ███▌ 
  ███    ███   ███    ███ ███    ███ ███    ███ ███  
  ███    ███   ███    ███ ███    ███ ███   ▄███ ███  
  ████████▀    ███    █▀  ████████▀  ████████▀  █▀   

Greetings $(whoami) .....

Gaudi is a tool that allows you to install a set of predefined software lists! 
Please make sure to follow the instructions carefully to avoid any unneeded installations.

The following script will set up your machine based on the various configurations specified in the config files

EOF

# Get the operating system and shell type
get_os
get_shell_type

[[ $GAUDI_SHELL != "bash" ]] && printf '\n%sgaudi requires bash as your interactive shell! Please adjust accordingly and re-run the setup%s\n' "$RED" "$NC" && exit 1

# Run installation steps
for step in "${SOURCE_LOCATION}/lib/${OS}/install-pre-requisits.sh" \
            "${SOURCE_LOCATION}/configs/configure-ssh.sh" \
            "${SOURCE_LOCATION}/configs/configure-gaudi.sh" \
            "${SOURCE_LOCATION}/lib/install-shell-helpers.sh" \
            "${SOURCE_LOCATION}/lib/install-software.sh" \
            "${SOURCE_LOCATION}/lib/${OS}/configure.sh"; do
    source "$step"
done

_echo "Setting up your machine with gaudi is finished! Enjoy"