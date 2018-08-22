#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Update .git branchesfrom the latest remote origin
# The command accepts two optional argument which is the new branch to checkout
    # If no argument was passed then the command will default and switch all repos to master
    # If a second argument is passed then it will from that remote, if not it will default to origin
    # Default paramteres: git pull origin master

update_git_branch() {
    BRANCH=${1:-master}
    REMOTE=${2:-origin}
    execute -g "git pull $REMOTE $BRANCH"
}