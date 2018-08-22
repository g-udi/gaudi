printf "\n${RED}

 ▄  █ ▄███▄   █    █ ▄▄  ▄███▄   █▄▄▄▄   ▄▄▄▄▄
█   █ █▀   ▀  █    █   █ █▀   ▀  █  ▄▀  █     ▀▄
██▀▀█ ██▄▄    █    █▀▀▀  ██▄▄    █▀▀▌ ▄  ▀▀▀▀▄
█   █ █▄   ▄▀ ███▄ █     █▄   ▄▀ █  █  ▀▄▄▄▄▀
   █  ▀███▀       ▀ █    ▀███▀     █
  ▀                  ▀            ▀

${NC}The Following script will install some shell helpers .. that depends on what shell you are using\n
Currently, this script offers helpers for zsh and bash. Before proceeding further, take a moment to read about each helper:

${YELLOW}bash-it${NC}   http://github.com/Bash-it/bash-it

Bash-it is a collection of community Bash commands and scripts. (And a shameless ripoff of oh-my-zsh)
Includes autocompletion, themes, aliases, custom functions, a few stolen pieces from Steve Losh, and more.

Bash-it provides a solid framework for using, developing and maintaining shell scripts and custom commands for your daily work.
If you're using the Bourne Again Shell (Bash) on a regular basis and have been looking for an easy way on how to keep all of
these nice little scripts and aliases under control, then Bash-it is for you!

${MAGENTA}Stop polluting your ~/bin directory and your .bashrc file, fork/clone Bash-it and start hacking away${NC}

${YELLOW}oh-my-zsh${NC}  http://github.com/robbyrussell/oh-my-zsh

Once installed, your terminal shell will become the talk of the town or your money back! With each keystroke in your command prompt
you'll take advantage of the hundreds of powerful plugins and beautiful themes. Strangers will come up to you in cafés and ask you, that is amazing!
\n
"
read -p "Do you need to install any of the shell helpers [recommended] ? [Y/N] " -n 1 </dev/tty;
echo ""
if [[ $REPLY =~ ^[yY]$ ]]; then
    read -p "Would you like to install bash-it ? [Y/N] " -n 1 </dev/tty;
    echo ""
    if [[ -d ${HOME}/.bash_it ]]; then
        printf "${MAGENTA}bash-it is already installed .. skipping${NC}\n"
    else
        if [[ $REPLY =~ ^[yY]$ ]]; then

            echo -e "The next step will prompt you for the url of a bash-it installation...\n"
            echo -e "${YELLOW}[D,d]${NC} will install the original bash-it from: ${MAGENTA}https://github.com/Bash-it/bash-it"
            echo -e "${YELLOW}[A,a]${NC} will install ahmadassaf's fork from: ${MAGENTA}https://github.com/ahmadassaf/bash-it"
            echo -e "\n${YELLOW}If you want to point to any other location then just type the github url of that repo${NC}"
            echo -e "\n${UNDERLINE_RED}Note"
            echo -e "${WHITE}The original bash-it and other forks have a corrupt installation script as they assume you are running the installation directly from the bash-it repo root.${NC}"
            echo -e "${RED}Keep an eye on the installation logs for any issues during the installation process${NC}"
            
            read -p "Please type url of the bash-it repo ? " BASH_IT_URL </dev/tty;
            echo ""
            export BASH_IT="${HOME}/.bash_it"
            if [[ $BASH_IT_URL =~ ^[dD]$ ]]; then
                BASH_IT_URL="https://github.com/Bash-it/bash-it"
            fi;
            if [[ $BASH_IT_URL =~ ^[aA]$ ]]; then
                BASH_IT_URL="https://github.com/ahmadassaf/bash-it"
            fi;
            git clone --depth=1 $BASH_IT_URL ~/.bash_it
            . ~/.bash_it/install.sh
        fi;
    fi;

    read -p "Would you like to install oh-my-zsh ? [Y/N] " -n 1 </dev/tty;
    echo ""

    if [[ $REPLY =~ ^[yY]$ ]]; then
        if [[ -d ${HOME}/.oh-my-zsh ]]; then
            printf "${MAGENTA}oh-my-zh is already installed .. skipping${NC}\n"
        else
            read -p "Please type url of the oh-my-zsh repo (e.g., robbyrussell/oh-my-zsh) ? Type [D] for the default oh-my-zsh: " OH_MY_ZSH_URL </dev/tty;
            echo ""
            if [[ $OH_MY_ZSH_URL =~ ^[dD]$ ]]; then
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
            else
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/$OH_MY_ZSH_URL/master/tools/install.sh)"
            fi;
        fi;
    fi
fi;

