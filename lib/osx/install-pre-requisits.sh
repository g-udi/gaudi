#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,SC2016

source "$SOURCE_LOCATION/lib/${OS}/config-sudo.sh"

echo -e "\nPreparing your machine by installing required software\n"

install_if_missing() {
    if ! command -v "$1" &> /dev/null; then
        echo "Installing $1..."
        $2
    else
        echo -e "${RED}$1 is installed${GREEN} ✓${NC}"
    fi
}

install_if_missing brew '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
install_if_missing mas 'brew install mas'
install_if_missing git 'brew install git'