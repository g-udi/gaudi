#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning apt cache"

sudo apt-get autoremove -y || gaudi::record_failure "apt-get autoremove"
sudo apt-get clean || gaudi::record_failure "apt-get clean"
