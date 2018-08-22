printf "\n\n${RED}Cleaning up now after installation ..... ${NC}\n\n"

brew cleanup -s
brew cask cleanup
brew prune