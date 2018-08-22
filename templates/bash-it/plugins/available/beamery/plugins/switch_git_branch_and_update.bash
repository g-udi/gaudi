#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Switch the branches of .git repos into a specific branch and update from the latest remote origin
# The command accepts two optional argument which is the new branch to checkout
    # If no argument was passed then the command will default and switch all repos to master
    # If a second argument is passed then it will from that remote, if not it will default to origin
    # Default paramteres: git checkout master; git pull origin master

switch_git_branch_and_update() {
    # if a second parameter is defined as a remote it will be used, if not then it will pull from origin
    BRANCH=${1:-master}
    REMOTE=${2:-origin}
    printf "${RED}Please note that this will stash any changes made in the repos and flip the current branch${NC}\nAre you sure you want to proceed? [Y/N] ? "  && read $REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! [[ "${BRANCH}" =~ "(master|development)" ]]; then
            printf "\nYou are switching to a non-default branch ... will fetch repositories first\n"
            execute -g "git fetch; git stash; git checkout $BRANCH; git pull $REMOTE $BRANCH"
        else
            printf "\nYou are switching to a default branch ... Switching\n"
            execute -g "git stash; git checkout $BRANCH; git pull $REMOTE $BRANCH"
        fi
    fi
}