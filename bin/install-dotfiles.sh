#!/usr/bin/env bash

read -p  "Would you like to install your dotfiles wtih stow?  " -n 1
if [[ $REPLY =~ ^[yY]$ ]]; then
    if ! type stow &> /dev/null; then
        printf "\n\n We noticed that stow is not installed on your machine .. Installing now ... \n" -n 1;
        brew install stow
    else
        printf "stow is installed ✓\n\n\n"
    fi

    if [ -d "$SOURCE_LOCATION/dotfiles" ]; then
        printf "We have your dotfiles"
    fi

fi;
