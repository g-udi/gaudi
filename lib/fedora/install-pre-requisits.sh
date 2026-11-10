#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing Fedora prerequisites"

# What Homebrew on Linux and most source builds need. curl is only added when
# it is missing: Fedora images ship curl-minimal, which conflicts with curl.
fedora_packages=(gcc gcc-c++ make procps-ng file git)
gaudi::command_exists curl || fedora_packages+=(curl)

sudo dnf install -y "${fedora_packages[@]}" || gaudi::record_failure "Fedora prerequisites (dnf install)"

if gaudi::command_exists brew; then
    :
elif gaudi::is_root; then
    gaudi::warn "Homebrew cannot be installed as root: run Gaudi as a regular user to install Brewfiles"
elif gaudi::confirm "Install Homebrew on Linux? It is required for Brewfiles." "n"; then
    gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \
        || gaudi::record_failure "Homebrew installation"
fi

if gaudi::command_exists brew; then
    gaudi::activate_brew || gaudi::warn "Homebrew could not be loaded into this shell"
fi
