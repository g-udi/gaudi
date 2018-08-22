#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Clean any local branches that have been deleted on remote

clean_git_local_branches() {
    execute -g "git branch --merged | egrep -v '(^\*|master|development)'| xargs -I {} git delete-branch {}"
    execute -g "git remote prune origin"
}