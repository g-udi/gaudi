echo "";
read -p "Would you like to clone all of the development repositories? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -L -O https://raw.githubusercontent.com/SeedJobs/git-beam-it/master/git-beam-it && sudo mv git-beam-it /usr/local/bin/ && sudo chmod +x /usr/local/bin/git-beam-it
    git beam-it -d '../' -t
fi;
