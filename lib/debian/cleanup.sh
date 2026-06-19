#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning apt cache"

sudo apt-get autoremove -y
sudo apt-get clean
