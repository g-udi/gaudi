#!/usr/bin/env bash
# shellcheck shell=bash

export EMAIL_REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

# Get the operating system version of the machine 
function getOperatingSystem {
    printf "\n%s\n" "[INFO] Getting bash version ...."
    bash --version
    case $(uname) in
    Linux )
        command -v yum && { export OS=centos; return; }
        command -v zypper && { export OS=opensuse; return; }
        command -v apt-get && { export OS=debian; return; }
        ;;
    Darwin )
        export OS=osx
        ;;
    * );;
    esac    
}

function _echo {
    [[ "$0" == "-zsh" ]] && echo "$@" || echo -e "$@"
}


# Checks if a command already exists
# e.g., command_exists brew
#   <Function> command: The command we want to check if it exists
function command_exists {
    type "$1" &> /dev/null ;
}