#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing Debian/Ubuntu prerequisites"

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    libssl-dev \
    procps

if ! gaudi::command_exists brew && gaudi::confirm "Install Homebrew on Linux for brew-based lists?" "n"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    gaudi::append_once "$GAUDI_SHELL_PROFILE" 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
elif [[ -d "$HOME/.linuxbrew" ]]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    gaudi::append_once "$GAUDI_SHELL_PROFILE" "eval \"\$($HOME/.linuxbrew/bin/brew shellenv)\""
fi
