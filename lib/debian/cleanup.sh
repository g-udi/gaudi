#!/usr/bin/env bash
# shellcheck shell=bash

printf "\n\n${RED}%s${NC}\n\n" "Cleaning up now after installation ....."

sudo apt-get autoremove
sudo apt-get clean