#!/usr/bin/env bash
# shellcheck shell=bash

printf "\n\n${RED}%s${NC}\n\n" "Cleaning up now after installation ....."

_brew cleanup -s
_brew cask cleanup
_brew prune