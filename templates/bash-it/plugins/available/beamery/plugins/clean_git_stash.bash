#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Clean any stashed commits

clean_git_stash() {
    BRANCH=${1:-master}
    printf "${RED}Please note that this will clear any stashes you have saved${NC}\nAre you sure you want to proceed? [Y/N] ? "  && read $REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        execute -g "git stash clear && echo '--> done'"
    fi
}