#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing Debian/Ubuntu prerequisites"

sudo apt-get update || gaudi::record_failure "apt-get update"
sudo apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    libssl-dev \
    procps || gaudi::record_failure "Debian prerequisites (apt-get install)"

if ! gaudi::command_exists brew && gaudi::confirm "Install Homebrew on Linux? It is required for Brewfiles." "n"; then
    gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \
        || gaudi::record_failure "Homebrew installation"
fi

if gaudi::command_exists brew; then
    gaudi::activate_brew || gaudi::warn "Homebrew could not be loaded into this shell"
fi
