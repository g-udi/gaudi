#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Clean unused NPM modules from each repo
# The function will check if npm-clean is installed and install it otherwise

clean_npm_modules() {

    if command_exists npm-clean ; then
        execute -n "npm-clean >> ../npm-clean-report.txt"
    else
        printf 'npm-check module was not found. Installing now:';
        npm install -g npm-clean
        execute -n "npm-clean >> ../npm-clean-report.txt"
    fi
}