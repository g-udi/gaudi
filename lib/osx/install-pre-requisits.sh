#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,SC2016

source "$SOURCE_LOCATION/lib/${OS}/config-sudo.sh"

printf "\nWe need to prepare your machine by install some required software\n\n"

if ! type brew &> /dev/null; then
    printf "%s\n" "We noticed that brew is not installed on your machine .. Installing now ...";
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    printf "${RED}%s$GREEN %s ${NC}" "brew is installed" "✓"
fi

# Add Homebrew's executable directory to the front of the PATH
if ! grep -q "^export PATH=/usr/local/bin:${PATH}$" ~/.bash_profile; then
    printf "${YELLOW}%s\n${NC}\n" "Updating shell profile for homebrew"
    echo "export PATH=/usr/local/bin:$PATH" >> "$GAUDI_SHELL_PROFILE"
    echo "export PATH=/opt/homebrew/bin" >> "$GAUDI_SHELL_PROFILE"
    [[ $GAUDI_SHELL == "zsh" ]] && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zshrc"
    
    # Make sure we add brew variables to the needed files
    source "$GAUDI_SHELL_PROFILE"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! type mas &> /dev/null; then
    printf "%s\n" "Installing mas is highly recommended .. sorry it is not up to you to decide ;)"
    brew install mas
else
    printf "${RED}%s$GREEN %s ${NC}" "mas is installed" "✓"
fi

if ! type git &> /dev/null; then
    printf "\n%s\n" "We noticed that git is not installed on your machine .. Installing now ...";
    brew install git
else
    printf "${RED}%s$GREEN %s ${NC}\n\n" "git is installed" "✓"
fi