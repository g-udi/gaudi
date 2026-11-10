#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Preparing openSUSE prerequisites"

# findutils and diffutils are listed because the minimal openSUSE image has
# neither, and Gaudi itself relies on find.
sudo zypper --non-interactive install gcc gcc-c++ make procps curl file git findutils diffutils \
    || gaudi::record_failure "openSUSE prerequisites (zypper install)"

gaudi::offer_linuxbrew
