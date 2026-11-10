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

gaudi::offer_linuxbrew
