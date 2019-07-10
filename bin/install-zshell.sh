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