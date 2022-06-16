#!/usr/bin/env bash
# shellcheck shell=bash

_echo "${RED}


 ▄  █ ▄███▄   █    █ ▄▄  ▄███▄   █▄▄▄▄   ▄▄▄▄▄
█   █ █▀   ▀  █    █   █ █▀   ▀  █  ▄▀  █     ▀▄
██▀▀█ ██▄▄    █    █▀▀▀  ██▄▄    █▀▀▌ ▄  ▀▀▀▀▄
█   █ █▄   ▄▀ ███▄ █     █▄   ▄▀ █  █  ▀▄▄▄▄▀
   █  ▀███▀       ▀ █    ▀███▀     █
  ▀                  ▀            ▀

${NC}The Following script will install some shell helpers .. that depends on what shell you are using\n
Currently, this script offers helpers for zsh and bash. Before proceeding further, take a moment to read about each helper:

${YELLOW}gaudi-bash${NC}   http://github.com/g-udi/gaudi-bash

gaudi-bash is a collection of community Bash commands and scripts. (And a shameless ripoff of oh-my-zsh)
Includes autocompletion, themes, aliases, custom functions, a few stolen pieces from Steve Losh, and more.

gaudi-bash provides a solid framework for using, developing and maintaining shell scripts and custom commands for your daily work.
If you're using the Bourne Again Shell (Bash) on a regular basis and have been looking for an easy way on how to keep all of
these nice little scripts and aliases under control, then gaudi-bash is for you!

${MAGENTA}Stop polluting your ~/bin directory and your .bashrc file, fork/clone gaudi-bash and start hacking away${NC}

${YELLOW}oh-my-zsh${NC}  http://github.com/robbyrussell/oh-my-zsh

Once installed, your terminal shell will become the talk of the town or your money back! With each keystroke in your command prompt
you'll take advantage of the hundreds of powerful plugins and beautiful themes. Strangers will come up to you in cafés and ask you, that is amazing!


"

function _install-gaudi-bash {
    
    echo ""
    printf "Would you like to install gaudi-bash ? [Y/N] ";
    
    if [[ $(read_answer) =~ ^[yY]$ ]]; then
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/g-udi/gaudi-bash/master/install.sh)" -s --basic
    fi;
}

function _install-oh-my-zsh {

    function __fetch-oh-my-zsh {
        0>/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -s --unattended
        
    }

    if [[ -d ${HOME}/.oh-my-zsh ]]; then
        printf "oh-my-zsh is already installed! Would you like to re-install it ? [Y/N] ";
        [[ $(read_answer) =~ ^[yY]$ ]] && rm -rf "${HOME}/.oh-my-zsh" && __fetch-oh-my-zsh
    else        
        printf "Would you like to install oh-my-zsh ? [Y/N] ";
        if [[ $(read_answer) =~ ^[yY]$ ]]; then
            __fetch-oh-my-zsh
        fi;
    fi

}

printf "Do you need to install any of the shell helpers [recommended] ? [Y/N] ";
if [[ $(read_answer) =~ ^[yY]$ ]]; then
    (_install-gaudi-bash)
    (_install-oh-my-zsh)
fi;
