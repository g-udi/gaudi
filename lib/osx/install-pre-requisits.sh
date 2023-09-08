#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,SC2016

source "$SOURCE_LOCATION/lib/${OS}/config-sudo.sh"

printf "\nWe need to prepare your machine by install some required software\n\n"


/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
printf "${RED}%s$GREEN %s ${NC}" "brew is installed" "✓"

brew install mas
printf "${RED}%s$GREEN %s ${NC}" "mas is installed" "✓"

if ! command_exists git; then
    printf "\n%s\n" "We noticed that git is not installed on your machine .. Installing now ...";
    brew install git
else
    printf "${RED}%s$GREEN %s ${NC}\n\n" "git is installed" "✓"
fi
