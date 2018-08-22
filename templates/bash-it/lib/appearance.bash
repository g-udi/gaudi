#!/usr/bin/env bash

export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:ex=01;32:*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:*.sh=01;32:*.csh=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.bz=01;31:*.tz=01;31:*.rpm=01;31:*.cpio=01;31:*.jpg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:*.png=01;35:*.tif=01;35:';

# colored grep
GREP_OPTIONS="--color=auto"
alias grep="grep $GREP_OPTIONS"

if [[ -z "$CUSTOM_THEME_DIR" ]]; then
    CUSTOM_THEME_DIR="${BASH_IT}/custom/themes"
fi

# Load the theme
if [[ $BASH_IT_THEME ]]; then
    if [[ -f "$CUSTOM_THEME_DIR/$BASH_IT_THEME/$BASH_IT_THEME.theme.bash" ]]; then
        source "$CUSTOM_THEME_DIR/$BASH_IT_THEME/$BASH_IT_THEME.theme.bash"
    else
        source "$BASH_IT/themes/$BASH_IT_THEME/$BASH_IT_THEME.theme.bash"
    fi
fi
