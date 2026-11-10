#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning dnf cache"

sudo dnf autoremove -y || gaudi::record_failure "dnf autoremove"
sudo dnf clean all || gaudi::record_failure "dnf clean"
