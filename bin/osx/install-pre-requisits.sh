printf "\nWe need to prepare your machine by install some required software\n\n"

if ! type brew &> /dev/null; then
    printf "We noticed that ${YELLOW}brew${NC} is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

printf "Installing cask and mas as they are highly recommended .. sorry it is not up to you to decide ;)\n"
brew tap caskroom/cask
brew install mas

if [[ $SHELL_TYPE = "bash" ]]; then
    if ! type bash &> /dev/null; then
        read -p "We noticed that you selected bash as your shell but it was not installed .. do you wish to install it ? [Y/N] " -n 1;
        echo "";
        if [[ $REPLY =~ ^[yY]$ ]]; then
            printf "\nInstalling bash shell"
            brew install bash
            sudo chsh -s /usr/local/bin/bash
        fi;
    fi
fi;

if [[ $SHELL_TYPE = "zsh" ]]; then
    if ! type zsh &> /dev/null; then
        read -p "We noticed that you selected zsh as your shell but it was not installed .. do you wish to install it ? [Y/N] " -n 1;
        echo "";
        if [[ $REPLY =~ ^[yY]$ ]]; then
            printf "\nInstalling zsh shell"
            brew install zsh
            sudo chsh -s /usr/local/bin/zsh
        fi;
    fi
fi;
