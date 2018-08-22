#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# List all the branches of a .git repository sorted by date creation
# This is useful to identify dead branches

audit_git_branches() {
    execute -g "git for-each-ref --sort='-authordate:iso8601' --format=' %(authordate:relative)%09%(refname:short)' refs/remotes"
}