#!/usr/bin/env bash
# shellcheck shell=bash

printf "Setting up SSH Installation...\n"

read -rp "Have you configured SSH? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Nn]$ ]]; then

	read -rp "What is the email address you want to configure SSH with? ";

	echo "Configuring SSH with email: $REPLY";
	ssh-keygen -t rsa -b 4096 -C "$REPLY" 
	# Add your key to the ssh-agent
	eval "$(ssh-agent -s)"
	ssh-add ~/.ssh/id_rsa

	printf "\n\n${RED}%s${NC}\n\n" "Please dont forget to add your id_rsa.pub key [below] to any service that requires it e.g., Github"

	# Add your SSH key to your account
	echo "";
	cat ~/.ssh/id_rsa.pub
	echo "";
fi;

