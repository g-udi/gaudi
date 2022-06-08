#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090

source "$SOURCE_LOCATION/lib/${OS}/config-sudo.sh"

printf "\nWe need to prepare your machine by install some required software\n\n"

if ! type brew &> /dev/null; then
    printf "%s\n" "We noticed that brew is not installed on your machine .. Installing now ..." -n 1;
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    printf "${RED}%s$GREEN %s ${NC}" "brew is installed" "✓"
fi

if ! type mas &> /dev/null; then
    printf "%s\n" "Installing mas is highly recommended .. sorry it is not up to you to decide ;)"
    brew install mas
else
    printf "${RED}%s$GREEN %s ${NC}" "mas is installed" "✓"
fi

if ! type git &> /dev/null; then
    printf "%s\n" "We noticed that git is not installed on your machine .. Installing now ..." -n 1;
    brew install git
else
    printf "${RED}%s$GREEN %s ${NC}\n\n" "git is installed" "✓"
fi