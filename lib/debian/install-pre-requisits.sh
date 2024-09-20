#!/usr/bin/env bash
# shellcheck shell=bash disable=2016

echo -e "\nPreparing your machine by installing required software\n"

sudo apt-get update && sudo apt-get upgrade -y

# Install requirements without prompt
sudo apt-get install -y build-essential libssl-dev apt-transport-https curl file

install_if_missing() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Installing $1..."
        sudo apt-get install -y "$2"
    fi
}

install_if_missing git git-all
install_if_missing brew "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

if command -v brew >/dev/null 2>&1; then
    test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
    test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.profile
fi