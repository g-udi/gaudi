#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2181

# alias to point to brew when its freshly installed
function gaudi_brew {
    if command_exists brew; then
        brew "$@"
    else
        /opt/homebrew/bin/brew "$@"
    fi
}

# alias to point to brew when its freshly installed
function mas {
    "$(brew)"/mas "$@"
}

# Get the operating system version of the machine 
function get_os {
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

function read_answer {
    options=${1:-yYnN}
    input=
    while [[ $input = "" ]]; do
        read -r -n 1 input
        ! [[ $input =~ ^[$options]$ ]] && printf "\n${RED}%s ${NC}%s " "[ERROR]" "Please enter a valid answer [yY|nN]" >&2 && unset input
    done
    [[ -n $input ]] && printf "\n" >&2 && echo "$input"
}

function read_email {
    local EMAIL_REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
    input=
    while [[ $input = "" ]]; do
        read -r input
        ! [[ $input =~ $EMAIL_REGEX ]] && printf "\n${RED}%s ${NC}%s " "[ERROR]" "Please enter a valid e-mail [yY|nN]" >&2 && unset input
    done
    [[ -n $input ]] && printf "\n" >&2 && echo "$input"
}

function read_git_url {
    input=
    while [[ $input = "" ]]; do
        read -r input
        GIT_ASKPASS=true git ls-remote "$input" > /dev/null 2>&1
        if [ "$?" -ne 0 ]; then
            printf "\n${RED}%s ${NC}%s ${YELLOW}%s ${NC}" "[ERROR]" "Unable to clone the repo in: $input" ">>> Please enter a new url:" >&2 && unset input
        fi
    done
    [[ -n $input ]] && printf "\n" >&2 && echo "$input"
}

# Gets the current shell type e.g., bash or zsh
# e.g., get_shell_type
function get_shell_type {
    if test -n "$ZSH_VERSION"; then
        export GAUDI_SHELL="zsh"
        export GAUDI_SHELL_PROFILE="$HOME/.zshrc"
    elif test -n "$BASH_VERSION"; then
        export GAUDI_SHELL="bash"
        export GAUDI_SHELL_PROFILE="$HOME/.bash_profile"
    fi
}


# Adapts echo to see if we can use the -e for bash or not for zsh
function _echo {
    [[ "$0" == "-zsh" ]] && echo "$@" || printf "%s" "$@"
}

# Checks if a command already exists
# e.g., command_exists brew
#   <Function> command: The command we want to check if it exists
function command_exists {
    type "$1" &> /dev/null ;
}

export gaudi_brew
export _echo
