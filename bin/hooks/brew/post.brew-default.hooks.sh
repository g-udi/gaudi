#!/usr/bin/env bash

printf "\n%s\n\n" "🔬 All brew formulas installed .. setting up few things"

echo -e "\nChecking if all brew installed formulas are healthy .. running brew doctor 👨🏻‍⚕️\n"
brew doctor

# # Add the new shell to the list of allowed shells
# # We need this to allow the usage of the new bash 4+ version to be the login shell
# sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
# # Change to the new shell
# chsh -s /usr/local/bin/bash 