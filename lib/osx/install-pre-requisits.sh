#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing macOS prerequisites"

if ! xcode-select -p >/dev/null 2>&1; then
    gaudi::warn "Xcode Command Line Tools are not installed. macOS will open the installer."
    xcode-select --install || true
fi

if ! gaudi::command_exists brew; then
    gaudi::log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

for package_name in git mas; do
    if ! gaudi::command_exists "$package_name"; then
        brew install "$package_name"
    else
        gaudi::success "$package_name is installed"
    fi
done
