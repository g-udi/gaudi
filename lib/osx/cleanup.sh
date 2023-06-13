#!/usr/bin/env bash
# shellcheck shell=bash

printf "\n\n${RED}%s${NC}\n\n" "Cleaning up now after installation ....."

brew cleanup -s
brew cask cleanup
brew prune