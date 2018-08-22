cite about-plugin
about-plugin 'beamery helpers functions'

#!/usr/bin/env bash

beamery() {

    if [ -d "${HOME}/.bash_it/plugins/available/beamery/plugins" ]; then
        for config_file in ${HOME}/.bash_it/plugins/available/beamery/plugins/*.bash
        do
          if [ -e "${config_file}" ]; then
            source $config_file
          fi
        done
    fi

    # Check if the second param passed is a call to the help .. if so launch the help if not .. execute the command
    if [[ $2 = "--help" ]]; then
        help $1
    else
    # Execute the command/function passed as an argument
        $@
    fi

    help() {
        if [[ $1 = "execute" ]]; then
            echo "Executes a passed command in each repository"
        else
            printf "\n" && grep '#' "$HOME/.bash_it/plugins/available/beamery/plugins/${1}.bash" | cut -c 2- | tail -n +3
        fi
    }
}