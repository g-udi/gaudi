printf "Setting up SSH Installation...\n"

read -p "Have you configured SSH? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Nn]$ ]]; then
	echo "Configuring SSH with email: $EMAIL";
	ssh-keygen -t rsa -b 4096 -C "$EMAIL"
	# Add your key to the ssh-agent
	eval "$(ssh-agent -s)"
	ssh-add ~/.ssh/id_rsa
fi;

printf "\n\n${RED}Please dont forget to add your id_rsa.pub key [below] to any service that requires it e.g., Github${NC}\n\n"

# Add your SSH key to your account
echo "";
cat ~/.ssh/id_rsa.pub
echo "";
