#!/usr/bin/env bash
# shellcheck shell=bash

_echo "

${YELLOW}
██████   ██████  ████████     ███████ ██ ██      ███████ ███████ 
██   ██ ██    ██    ██        ██      ██ ██      ██      ██      
██   ██ ██    ██    ██        █████   ██ ██      █████   ███████ 
██   ██ ██    ██    ██        ██      ██ ██      ██           ██ 
██████   ██████     ██        ██      ██ ███████ ███████ ███████ 
                                                                 
${NC}
Managing dotfiles can be tricky when you have multiple machines. 
Fortunately, there’s a beautifully simple tool that makes this easy: GNU Stow. 
If you have dotfiles that you want to share across multiple machines, or manage revisions, GNU Stow will make it easy.

${BLUE}
GNU Stow is a symlink farm manager which takes distinct packages of software and/or data located in separate directories on the filesystem, and makes them appear to be installed in the same place.
${NC}

${MAGENTA}How it works?${NC}
The basic premise of GNU Stow is that it takes files in multiple directories, and manages symlinks to make them appear in one directory.

When invoked with a directory as an argument, stow simply changes into that directory, and creates a symlink for everything it contains to the parent directory.
When invoked with many directories as arguments, it does this for each directory listed.

"

printf  "Would you like to install your dotfiles wtih stow? "
if [[ $(read_answer) =~ ^[yY]$ ]]; then
    if ! command_exists stow; then
        printf "\n\n%s\n" "We noticed that stow is not installed on your machine .. Installing now ..."
        brew install stow
    else
        printf "\n${RED}%s$GREEN %s ${NC}\n\n" "stow is installed" "✓"
    fi
fi

if [[ -d "$GAUDI_TEMPLATES_LOCATION/dotfiles" ]]; then
    for dotfile in "$GAUDI_TEMPLATES_LOCATION"/dotfiles/* ; do
            file=$(basename "$dotfile")
            printf "${MAGENTA}%s ${WHITE}%s ${GREEN}%s ${NC}\n" "[STOW]" "Linking $dotfile" "✓"
            stow "$file" -d "$GAUDI_TEMPLATES_LOCATION"/templates/dotfiles/ -t "$HOME"
    done
fi