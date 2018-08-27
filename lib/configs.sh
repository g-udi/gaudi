#!/usr/bin/env bash

source "$SOURCE_LOCATION/lib/colors.sh"

export EMAIL_REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

# Get the logged in username
export USER=$(whoami)

# Get the operating system version of the machine 
# https://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script
getOperatingSystem () {
    echo -e "\n[INFO] Getting bash version .... \n"
    bash --version
    case `uname` in
    Linux )
        LINUX=1
        which yum && { export OS=centos; return; }
        which zypper && { export OS=opensuse; return; }
        which apt-get && { export OS=debian; return; }
        ;;
    Darwin )
        DARWIN=1
        export OS=osx
        ;;
    * );;
    esac    
}  

# Install software from a software list definition 
# e.g., installSoftwareList "brew install" "false" "${brewList[@]}"
#   <Function> command: The install command to execute on an install item
#   <Boolean> withPrompt: Indicate if we need to prompt the user to accept the installation of each item
#   <Array> softwareList: The software list reference
installSoftwareList () {
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
            read -p "👾 $(echo -e "${MAGENTA}$software${NC}\n${YELLOW}Description:${NC} $softwareDescription") | Would you like to install this? [Y/N] " -n 1 </dev/tty
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                `echo ${installCommand} ${software}`
            fi;
        else
            echo -e "\n👾 Installing ${MAGENTA}$software${NC}\n${YELLOW}Description:${NC} $softwareDescription"
            `echo ${installCommand} ${software}`
        fi
    done
}

command_exists () {
    type "$1" &> /dev/null ;
}

export -f command_exists
export -f installSoftwareList
export -f getOperatingSystem