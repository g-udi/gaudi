#!/usr/bin/env bash

if command_exists heroku ; then
    echo "⚙️  Configuring Heroku and adding autocompletion..."
    heroku update </dev/tty && heroku autocomplete </dev/tty
    if grep -q "HEROKU_AC_BASH_SETUP_PATH" ~/.bash_profile; then 
        echo "✅  Heroku autocomplete entry already found ...";
    else
        echo "$(heroku autocomplete:script bash)" >> ~/.bash_profile
    fi
fi