#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Switch the branches of .git repos into a specific branch
# The command accepts an optional argument which is the new branch to checkout
# If no argument was passed then the command will default and switch all repos to master
    # Default paramteres: git checkout master

switch_git_branch() {
    BRANCH=${1:-master}
    printf "${RED}Please note that this will stash any changes made in the repos and flip the current branch${NC}\nAre you sure you want to proceed? [Y/N] ? " && read $REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! [[ "${BRANCH}" =~ "(master|development)" ]]; then
            printf "\nYou are switching to a non-default branch ... fetching first\n"
            execute -g "git fetch; git stash; git checkout $BRANCH"
        else
            printf "\nYou are switching to a default branch ... Switching\n"
            execute -g "git stash; git checkout $BRANCH"
        fi
    fi
}