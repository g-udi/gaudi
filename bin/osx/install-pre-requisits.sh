printf "\nWe need to prepare your machine by install some required software\n\n"

if ! type brew &> /dev/null; then
    printf "We noticed that brew is not installed on your machine .. Installing now ... \n" -n 1;
    # Install Homebrew .. a must !
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

printf "Installing cask and mas as they are highly recommended .. sorry it is not up to you to decide ;)\n"
brew tap caskroom/cask
brew install mas

if ! type git &> /dev/null; then
    printf "We noticed that git is not installed on your machine .. Installing now ... \n" -n 1;
    brew install git
fi

