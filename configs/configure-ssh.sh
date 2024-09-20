#!/usr/bin/env bash
# shellcheck shell=bash

echo "Setting up SSH Installation..."
read -rp "Have you configured SSH? [Y/N] " configured_ssh

if [[ $configured_ssh =~ ^[Nn]$ ]]; then
    read -rp "Email address for SSH configuration: " EMAIL
    
    ssh-keygen -t rsa -b 4096 -C "$EMAIL"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa

    echo -e "\n${RED}Please add your id_rsa.pub key [below] to any service that requires it (e.g., Github)${NC}\n"
    cat ~/.ssh/id_rsa.pub
    echo
fi