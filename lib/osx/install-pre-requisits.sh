#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing macOS prerequisites"

if ! gaudi::command_exists brew; then
    gaudi::log "Installing Homebrew (this also installs the Xcode Command Line Tools)"
    if [[ "${GAUDI_ASSUME_YES:-false}" == "true" ]]; then
        (
            export NONINTERACTIVE=1
            gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        ) || gaudi::record_failure "Homebrew installation"
    else
        gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \
            || gaudi::record_failure "Homebrew installation"
    fi
fi

# Load brew into this run and into the shell profile, so new shells find it
gaudi::activate_brew || gaudi::warn "Homebrew is not available: brew-based steps will be skipped"

if ! xcode-select -p >/dev/null 2>&1; then
    gaudi::warn "Xcode Command Line Tools are not installed. Finish the installer that opens, then rerun gaudi setup."
    xcode-select --install || true
fi

if gaudi::command_exists brew; then
    for package_name in git mas; do
        if ! gaudi::command_exists "$package_name"; then
            brew install "$package_name" || gaudi::record_failure "$package_name (brew install)"
        else
            gaudi::success "$package_name is installed"
        fi
    done
fi
