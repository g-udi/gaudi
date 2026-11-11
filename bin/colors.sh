#!/usr/bin/env bash
# shellcheck shell=bash

# The colours Gaudi prints with. They hold escape sequences as text (print
# them with printf "%b"), and are empty unless the output is a terminal that
# supports colours.

NC=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
MAGENTA=""

ncolors=0
if command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ]; then
    ncolors=$(tput colors 2>/dev/null || printf 0)
fi

if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    NC="\\033[0m"
    RED="\\033[0;31m"
    GREEN="\\033[0;32m"
    YELLOW="\\033[0;33m"
    BLUE="\\033[0;34m"
    MAGENTA="\\033[0;35m"
fi

export NC RED GREEN YELLOW BLUE MAGENTA
