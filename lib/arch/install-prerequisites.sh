#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing Arch Linux prerequisites"

# -Sy refreshes the package database first; --needed skips what is installed
sudo pacman -Sy --noconfirm --needed base-devel procps-ng curl file git \
    || gaudi::record_failure "Arch prerequisites (pacman)"

gaudi::offer_linuxbrew
