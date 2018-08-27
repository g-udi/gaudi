#!/usr/bin/env bash

echo -e "\n\n🛰   All brew formulas are now installed ..."

echo -e "\nChecking if all brew installed formulas are healthy .. running brew doctor 👨🏻‍⚕️\n"
brew doctor

# Update global git config
git lfs install

if command_exists ghi ; then
    read -p "⚙️  Configuring ghi ... What is your github username ? " GITHUB_USERNAME </dev/tty && ghi config --auth ${GITHUB_USERNAME} </dev/tty  
fi

echo "⚙️  Setting up launchd to start clipper now and restart at login"
brew services start clipper

if command_exists heroku ; then
    echo "⚙️  Configuring heroku and adding autocompletion..."
    heroku update && heroku autocomplete
    printf "$(heroku autocomplete:script bash)" >> ~/.bash_profile; source ~/.bash_profile
fi

# if command_exists mvim ; then
#     export VISUAL="mvim --nofork"
# fi

# if command_exists mvim ; then
#     export VISUAL="mvim --nofork"
# fi

# if command_exists mvim ; then
#     export VISUAL="mvim --nofork"
# fi

#   Bash completion has been installed to:
#   /usr/local/etc/bash_completion.d

# zsh completions and functions have been installed to:
#   /usr/local/share/zsh/site-functions