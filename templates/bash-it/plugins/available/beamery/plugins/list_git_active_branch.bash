#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# List the current branches on the repos
# This is useful to know which branches are flipped on which repos

list_git_active_branch() {
    if [[ $IS_HIDDEN_FOLDER = 1 ]]; then
        find . -maxdepth 1 -type d \( ! -name . \) -exec bash -c "cd '{}' && test -d ".git" && printf 'Repository: ${MAGENTA}'{}'${NC} is on branch: ${YELLOW}' &&  git branch | grep '^\*' | cut -d' ' -f2 && printf '${NC}'" \;
    else
        find . -maxdepth 1 -type d \( ! -name ".*" \) -exec bash -c "cd '{}' && test -d ".git" && printf 'Repository: ${MAGENTA}'{}'${NC} is on branch: ${YELLOW}' &&  git branch | grep '^\*' | cut -d' ' -f2 && printf '${NC}'" \;
    fi

}