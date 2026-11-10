#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Cleaning zypper cache"

sudo zypper --non-interactive clean --all || gaudi::record_failure "zypper cache cleanup"
