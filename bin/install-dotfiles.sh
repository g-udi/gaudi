#!/usr/bin/env bash

if [ -d "$SOURCE_LOCATION/gaudi-files/dotfiles" ]; then
        for d in $SOURCE_LOCATION/gaudi-files/dotfiles/* ; do
            if [ -d "$d" ]; then
                file=`basename $d`
                echo "$file"
                stow $file -d $SOURCE_LOCATION/gaudi-files/dotfiles/ -t $HOME
            fi
        done
    fi

# read -p  "Would you like to install your dotfiles wtih stow?  " -n 1

# if [[ $REPLY =~ ^[yY]$ ]]; then
#     if ! type stow &> /dev/null; then
#         printf "\n\n We noticed that stow is not installed on your machine .. Installing now ... \n" -n 1;
#         brew install stow
#     else
#         printf "stow is installed ✓\n\n\n"
#     fi


# if [ -d "$SOURCE_LOCATION/gaudi-files/dotfiles" ]; then
#         for d in $SOURCE_LOCATION/gaudi-files/dotfiles/* ; do
#             if [ -d "$d" ]; then
#                 file=`basename $d`
#                 echo "$file"
#                 # stow $file --target="/Users/michael/"
#             fi
#         done
#     fi
# fi;
