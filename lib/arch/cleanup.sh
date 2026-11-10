#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning pacman cache"

sudo pacman -Sc --noconfirm || gaudi::record_failure "pacman cache cleanup"
