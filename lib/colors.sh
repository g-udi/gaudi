#!/usr/bin/env bash

# Use colors, but only if connected to a terminal, and that terminal supports them

if which tput >/dev/null 2>&1; then
    ncolors=$(tput colors)
fi

if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then

    # Reset
    export NC="\033[0m"       # Text Reset

    # Regular Colors
    export BLACK="\033[0;30m"        # Black
    export RED="\033[0;31m"          # Red
    export GREEN="\033[0;32m"        # Green
    export YELLOW="\033[0;33m"       # Yellow
    export BLUE="\033[0;34m"         # Blue
    export MAGENTA="\033[0;35m"      # magenta
    export CYAN="\033[0;36m"         # Cyan
    export WHITE="\033[0;37m"        # White

    # Bold
    export BOLD_BLACK="\033[1;30m"       # Black
    export BOLD_RED="\033[1;31m"         # Red
    export BOLD_GREEN="\033[1;32m"       # Green
    export BOLD_YELLOW="\033[1;33m"      # Yellow
    export BOLD_BLUE="\033[1;34m"        # Blue
    export BOLD_MAGENTA="\033[1;35m"     # magenta
    export BOLD_CYAN="\033[1;36m"        # Cyan
    export BOLD_WHITE="\033[1;37m"       # White

    # Underline
    export UNDERLINE_BLACK="\033[4;30m"       # Black
    export UNDERLINE_RED="\033[4;31m"         # Red
    export UNDERLINE_GREEN="\033[4;32m"       # Green
    export UNDERLINE_YELLOW="\033[4;33m"      # Yellow
    export UNDERLINE_BLUE="\033[4;34m"        # Blue
    export UNDERLINE_MAGENTA="\033[4;35m"     # magenta
    export UNDERLINE_CYAN="\033[4;36m"        # Cyan
    export UNDERLINE_WHITE="\033[4;37m"       # White

    # Background
    export BACKGROUND_BLACK="\033[40m"       # Black
    export BACKGROUND_RED="\033[41m"         # Red
    export BACKGROUND_GREEN="\033[42m"       # Green
    export BACKGROUND_YELLOW="\033[43m"      # Yellow
    export BACKGROUND_BLUE="\033[44m"        # Blue
    export BACKGROUND_MAGENTA="\033[45m"     # magenta
    export BACKGROUND_CYAN="\033[46m"        # Cyan
    export BACKGROUND_WHITE="\033[47m"       # White

    # High Intensty
    export INTENSE_BLACK="\033[0;90m"       # Black
    export INTENSE_RED="\033[0;91m"         # Red
    export INTENSE_GREEN="\033[0;92m"       # Green
    export INTENSE_YELLOW="\033[0;93m"      # Yellow
    export INTENSE_BLUE="\033[0;94m"        # Blue
    export INTENSE_MAGENTA="\033[0;95m"     # magenta
    export INTENSE_CYAN="\033[0;96m"        # Cyan
    export INTENSE_WHITE="\033[0;97m"       # White

    # Bold High Intensty
    export BOLD_INTENSE_BLACK="\033[1;90m"      # Black
    export BOLD_INTENSE_RED="\033[1;91m"        # Red
    export BOLD_INTENSE_GREEN="\033[1;92m"      # Green
    export BOLD_INTENSE_YELLOW="\033[1;93m"     # Yellow
    export BOLD_INTENSE_BLUE="\033[1;94m"       # Blue
    export BOLD_INTENSE_MAGENTA="\033[1;95m"    # magenta
    export BOLD_INTENSE_CYAN="\033[1;96m"       # Cyan
    export BOLD_INTENSE_WHITE="\033[1;97m"      # White

    # High Intensty backgrounds
    export BACKGROUND_INTENSE_BLACK="\033[0;100m"   # Black
    export BACKGROUND_INTENSE_RED="\033[0;101m"     # Red
    export BACKGROUND_INTENSE_GREEN="\033[0;102m"   # Green
    export BACKGROUND_INTENSE_YELLOW="\033[0;103m"  # Yellow
    export BACKGROUND_INTENSE_BLUE="\033[0;104m"    # Blue
    export BACKGROUND_INTENSE_MAGENTA="\033[10;95m" # magenta
    export BACKGROUND_INTENSE_CYAN="\033[0;106m"    # Cyan
    export BACKGROUND_INTENSE_WHITE="\033[0;107m"   # White

else

    export NC=""
    export BLACK=""
    export RED=""
    export GREEN=""
    export YELLOW=""
    export BLUE=""
    export MAGENTA=""
    export CYAN=""
    export WHITE=""

    export BOLD_BLACK=""
    export BOLD_RED=""
    export BOLD_GREEN=""
    export BOLD_YELLOW=""
    export BOLD_BLUE=""
    export BOLD_MAGENTA=""
    export BOLD_CYAN=""
    export BOLD_WHITE=""

    export UNDERLINE_BLACK=""
    export UNDERLINE_RED=""
    export UNDERLINE_GREEN=""
    export UNDERLINE_YELLOW=""
    export UNDERLINE_BLUE=""
    export UNDERLINE_MAGENTA=""
    export UNDERLINE_CYAN=""
    export UNDERLINE_WHITE=""

    export BACKGROUND_BLACK=""
    export BACKGROUND_RED=""
    export BACKGROUND_GREEN=""
    export BACKGROUND_YELLOW=""
    export BACKGROUND_BLUE=""
    export BACKGROUND_MAGENTA=""
    export BACKGROUND_CYAN=""
    export BACKGROUND_WHITE=""

    export INTENSE_BLACK=""
    export INTENSE_RED=""
    export INTENSE_GREEN=""
    export INTENSE_YELLOW=""
    export INTENSE_BLUE=""
    export INTENSE_MAGENTA=""
    export INTENSE_CYAN=""
    export INTENSE_WHITE=""

    export BOLD_INTENSE_BLACK=""
    export BOLD_INTENSE_RED=""
    export BOLD_INTENSE_GREEN=""
    export BOLD_INTENSE_YELLOW=""
    export BOLD_INTENSE_BLUE=""
    export BOLD_INTENSE_MAGENTA=""
    export BOLD_INTENSE_CYAN=""
    export BOLD_INTENSE_WHITE=""

    export BACKGROUND_INTENSE_BLACK=""
    export BACKGROUND_INTENSE_RED=""
    export BACKGROUND_INTENSE_GREEN=""
    export BACKGROUND_INTENSE_YELLOW=""
    export BACKGROUND_INTENSE_BLUE=""
    export BACKGROUND_INTENSE_MAGENTA=""
    export BACKGROUND_INTENSE_CYAN=""
    export BACKGROUND_INTENSE_WHITE=""

fi
