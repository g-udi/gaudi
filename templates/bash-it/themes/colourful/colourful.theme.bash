SCM_THEME_PROMPT_PREFIX=""
SCM_THEME_PROMPT_SUFFIX=""

SCM_THEME_PROMPT_DIRTY=" ${blinking_red}● ${normal}"
SCM_THEME_PROMPT_CLEAN=" ${bold_green}● ${normal}"
SCM_GIT_CHAR="${bold_green}git${normal}"
SCM_SVN_CHAR="${bold_cyan}svn${normal}"
SCM_HG_CHAR="${bold_red}☿${normal}"

#Mysql Prompt
export MYSQL_PS1="(\u@\h) [\d]> "

case $TERM in
        xterm*)
        TITLEBAR="${cyan}\w${normal}"
        ;;
        *)
        TITLEBAR=""
        ;;
esac

PS3=">> "

__my_rvm_ruby_version() {
    local gemset=$(echo $GEM_HOME | awk -F'@' '{print $2}')
  [ "$gemset" != "" ] && gemset="@$gemset"
    local version=$(echo $MY_RUBY_HOME | awk -F'-' '{print $2}')
    local full="$version$gemset"
  [ "$full" != "" ] && echo "[$full]"
}

is_vim_shell() {
        if [ ! -z "$VIMRUNTIME" ]
        then
                echo "[${cyan}vim shell${normal}]"
        fi
}

modern_scm_prompt() {
        CHAR=$(scm_char)
        if [ $CHAR = $SCM_NONE_CHAR ]
        then
                return
        else
                echo "${purple}[${green}$(scm_char)${purple}][${blue}$(scm_prompt_info)${purple}]${normal}"
        fi
}

prompt() {
    my_ps_host="${bold_yellow}\h${normal}";
    my_ps_user="${red}\u${normal}";
    my_ps_root="${red}\u${normal}";
    my_ps_path="${cyan}\w${normal}";


    # nice prompt
    PS1="\[\e]0;\u@\h: \w\a\]${purple}┌─[$my_ps_root${purple}][$my_ps_host${purple}][${my_ps_path}${purple}]$(modern_scm_prompt)$(__my_rvm_ruby_version)$(is_vim_shell)
${purple}└─▪ ${reset_color}"
}

PS2="${purple}└─▪ ${reset_color}"


PROMPT_COMMAND=prompt
