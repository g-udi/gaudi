#!/usr/bin/env bash

read -p  "${MAGENTA} Would you prefer to use ZSH?: ${NC}"
if [[ $REPLY =~ ^[yY]$ ]]; then
      if [ ! -n $(which zsh) ]; then
            brew install zsh
            zsh_path=$(which zsh)
            grep -Fxq "$zsh_path" /etc/shells || sudo bash -c "echo $zsh_path >> /etc/shells"
            sudo dscl . -create /Users/$USER UserShell zsh_path
      else
            if [ !$(brew list | grep zsh) ]; then
                  printf "You already have ZSH installed, its most likely the default zsh \n"
                  read -p "Would you like to install with brew instead?"
                  if [[ $REPLY =~ ^[yY]$ ]]; then
                        brew install zsh
                        sudo dscl . -create /Users/$USER UserShell /usr/local/bin/zsh
                  fi
            fi
      fi

fi;
# read -p "Do you need to install any of the shell helpers [recommended] ? [Y/N] " -n 1 </dev/tty;
# echo ""
# if [[ $REPLY =~ ^[yY]$ ]]; then
#     if [[ -d ${HOME}/.bash_it ]]; then
#         printf "${MAGENTA}bash-it is already installed .. skipping${NC}\n"
#     else
#         read -p "Would you like to install bash-it ? [Y/N] " -n 1 </dev/tty;
#         echo ""
#         if [[ $REPLY =~ ^[yY]$ ]]; then

#             printf "The next step will prompt you for the url of a bash-it installation...\n\n"
#             printf "\t${YELLOW}[D,d]${NC} will install the original bash-it from: ${MAGENTA}https://github.com/Bash-it/bash-it \n"
#             printf "\t${YELLOW}[A,a]${NC} will install ahmadassaf's fork from: ${MAGENTA}https://github.com/ahmadassaf/bash-it \n"
#             printf "\t${YELLOW}If you want to point to any other location then just type the github url of that repo${NC} \n"
#             printf "\n${UNDERLINE_RED}Note${NC}"
#             printf "\n${WHITE}The original bash-it and other forks have a corrupt installation script as they assume you are running the installation directly from the bash-it repo root.${NC}"
#             printf "\n${RED}Keep an eye on the installation logs for any issues during the installation process${NC} \n"

#             read -p "Please type url of the bash-it repo ? " BASH_IT_URL </dev/tty;
#             echo ""
#             export BASH_IT="${HOME}/.bash_it"
#             if [[ $BASH_IT_URL =~ ^[dD]$ ]]; then
#                 BASH_IT_URL="https://github.com/Bash-it/bash-it"
#             fi;
#             if [[ $BASH_IT_URL =~ ^[aA]$ ]]; then
#                 BASH_IT_URL="https://github.com/ahmadassaf/bash-it"
#             fi;
#             git clone --depth=1 $BASH_IT_URL ~/.bash_it && . ~/.bash_it/install.sh
#         fi;
#     fi;

#     if [[ ${HOME}/.oh-my-zsh ]]; then
#         printf "${MAGENTA}oh-my-zh is already installed .. skipping${NC}\n"
#     else
#         read -p "Would you like to install oh-my-zsh ? [Y/N] " -n 1 </dev/tty;
#         echo ""
#         if [[ $REPLY =~ ^[yY]$ ]]; then
#             read -p "Please type url of the oh-my-zsh repo (e.g., robbyrussell/oh-my-zsh) ? Type [D] for the default oh-my-zsh: " OH_MY_ZSH_URL </dev/tty;
#             echo ""
#             if [[ $OH_MY_ZSH_URL =~ ^[dD]$ ]]; then
#                 bash -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
#             else
#                 bash -c "$(curl -fsSL https://raw.githubusercontent.com/$OH_MY_ZSH_URL/master/tools/install.sh)"
#             fi;
#         fi;
#     fi
# fi;
