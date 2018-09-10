#!/usr/bin/env bash

echo "Checking if npm is installed 🤔"
if ! type npm &> /dev/null ; then
    printf "The required ${YELLOW}npm${NC} command was not found 😱 ..\n"
    echo "this might be due to the fact that you need to resource your .bashrc/.bash_profile or .zshrc\nPlease do that and then relaunch the script\n"
fi