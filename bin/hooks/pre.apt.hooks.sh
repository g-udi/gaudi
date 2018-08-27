#!/usr/bin/env bash

# Adding Docker keys
printf "Adding pre-requisite configs for ${YELLOW}Docker${NC}\n"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-cache policy docker-ce

sudo apt-get update