#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,SC2016

source "$SOURCE_LOCATION/lib/${OS}/config-sudo.sh"

printf "\nWe need to prepare your machine by install some required software\n\n"

if ! command_exists brew; then
    printf "%s\n" "We noticed that brew is not installed on your machine .. Installing now ...";
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    printf "${RED}%s$GREEN %s ${NC}" "brew is installed" "✓"
fi

if ! command_exists mas; then
    printf "%s\n" "Installing mas is highly recommended .. sorry it is not up to you to decide ;)"
    brew install mas
else
    printf "${RED}%s$GREEN %s ${NC}" "mas is installed" "✓"
fi

if ! command_exists git; then
    printf "\n%s\n" "We noticed that git is not installed on your machine .. Installing now ...";
    brew install git
else
    printf "${RED}%s$GREEN %s ${NC}\n\n" "git is installed" "✓"
fi