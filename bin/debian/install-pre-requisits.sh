printf "\n${RED}We need to prepare your machine by install some required software${NC}\n\n"

# Updating apt to refresh repos
sudo apt-get update
sudo apt-get upgrade

# Install requirements without prompt
sudo apt-get install build-essential
sudo apt-get install libssl-dev
sudo apt-get install apt-transport-https
sudo apt-get curl
sudo apt-get file

if ! type git &> /dev/null; then
    printf "We noticed that ${YELLOW}git${NC} is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    sudo apt-get install git-all
fi

if ! type brew &> /dev/null; then
    printf "We noticed that ${YELLOW}brew${NC} is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
    test -d ~/.linuxbrew && PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH"
    test -d /home/linuxbrew/.linuxbrew && PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    test -r ~/.bash_profile && echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.bash_profile
    echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.profile
fi

if [[ $SHELL_TYPE = "zsh" ]]; then
    if ! type zsh &> /dev/null; then
        read -p "We noticed that you selected zsh as your shell but it was not installed .. do you wish to install it ? [Y/N] " -n 1;
        echo "";
        if [[ $REPLY =~ ^[yY]$ ]]; then
            printf "\nInstalling ${RED}zsh shell${NC} shell"
            sudo apt-get install zsh
            sudo wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
            sudo chsh -s `which zsh`
        fi;
    fi
fi;