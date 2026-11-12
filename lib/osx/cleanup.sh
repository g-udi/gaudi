#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning Homebrew cache"

if gaudi::command_exists brew; then
    brew cleanup -s || gaudi::record_failure "brew cleanup"
else
    gaudi::warn "Skipping cleanup: brew is not installed"
fi
