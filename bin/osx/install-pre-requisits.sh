#!/usr/bin/env bash

printf "\nWe need to prepare your machine by install some required software\n\n"

if ! type brew &> /dev/null; then
    printf "We noticed that brew is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    printf "brew is installed ✓"
fi

if ! type mas &> /dev/null; then
    printf "Installing mas is highly recommended .. sorry it is not up to you to decide ;)\n"
    brew install mas
else
    printf "mas is installed ✓"
fi

if ! type git &> /dev/null; then
    printf "We noticed that git is not installed on your machine .. Installing now ... \n" -n 1;
    brew install git
else
    printf "git is installed ✓\n\n\n"
fi
