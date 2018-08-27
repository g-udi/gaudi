#!/usr/bin/env bash

printf "\nWe need to prepare your machine by install some required software\n\n"

# Updating apt to refresh repos
sudo apt-get update
sudo apt-get upgrade

# Install requirements without prompt
sudo apt-get install build-essential
sudo apt-get install libssl-dev
sudo apt-get install apt-transport-https
sudo apt-get curl
sudo apt-get file

if ! type git &> /dev/null; then
    printf "We noticed that git is not installed on your machine .. Installing now ... \n" -n 1;
    # Install git .. a must !
    sudo apt-get install git-all
fi

if ! type brew &> /dev/null; then
    printf "We noticed that brew is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
    test -d ~/.linuxbrew && PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH"
    test -d /home/linuxbrew/.linuxbrew && PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    test -r ~/.bash_profile && echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.bash_profile
    echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.profile
fi