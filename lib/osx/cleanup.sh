#!/usr/bin/env bash
# shellcheck shell=bash

printf "\n\n${RED}%s${NC}\n\n" "Cleaning up now after installation ....."

gaudi_brew cleanup -s
gaudi_brew cask cleanup
gaudi_brew prune