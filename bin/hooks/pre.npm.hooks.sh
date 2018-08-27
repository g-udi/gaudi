#!/usr/bin/env bash

echo -e "Checking if npm is installed 🤔"
if ! type npm &> /dev/null ; then
    echo -e "The required ${YELLOW}npm${NC} command was not found 😱 .."
    echo -e "this might be due to the fact that you need to resource your .bashrc/.bash_profile or .zshrc\nPlease do that and then relaunch the script"
fi