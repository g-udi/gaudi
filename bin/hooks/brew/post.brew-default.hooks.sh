echo "🛰   All brew formulas are now installed ..."

echo "Checking if all brew installed formulas are healthy .. running brew doctor 👨🏻‍⚕️"
brew doctor

# Update global git config
git lfs install

if command_exists ghi ; then
    read -p "⚙️  Configuring ghi ... What is your github username ? " GITHUB_USERNAME
    ghi config --auth ${GITHUB_USERNAME}
fi

echo "⚙️  Setting up launchd to start clipper now and restart at login"
brew services start clipper

if command_exists heroku ; then
    echo "⚙️  Configuring heroku and adding autocompletion..."
    heroku Update
    heroku autocomplete
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