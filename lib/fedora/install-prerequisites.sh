#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing Fedora prerequisites"

# What Homebrew on Linux and most source builds need. curl is only added when
# it is missing: Fedora images ship curl-minimal, which conflicts with curl.
fedora_packages=(gcc gcc-c++ make procps-ng file git)
gaudi::command_exists curl || fedora_packages+=(curl)

sudo dnf install -y "${fedora_packages[@]}" || gaudi::record_failure "Fedora prerequisites (dnf install)"

gaudi::offer_linuxbrew
