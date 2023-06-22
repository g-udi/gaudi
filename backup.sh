#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1036,SC1056,SC1072,SC1073,SC1009

# @function ProgressBar
# @description Show a progress bar animation by rendering a progress bar between a start and end value
function ProgressBar {
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done

    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

    printf "\rProgress : [${_fill// /#}${_empty// /-}] ${_progress}%%"

}

# @function backup_npm
# @description Backup the list of globally installed npm packages
function backup_npm {
    _start=1
    _end=$(npm list -g --depth 0 -p 2>/dev/null | sed -e '1d' | wc -l)
     npm list -g --depth 0 -p -l 2>/dev/null | sed -e '1d' | \
    while read i
        do
            app="${i#*:}"
            app_info=$(npm view "$app" 2>/dev/null | sed -n '3 p')
            echo "\"$app::$app_info\"" >> backup/default.npm.list.sh
            ProgressBar ${_start} ${_end}
            ((_start=_start+1))
    done
    echo ""
}

# @function backup_pip
# @description Backup the list of globally installed pip packages
function backup_pip {
    _start=1
    _end=$(pip list --user 2>/dev/null | sed -e '1,2d' | wc -l)
    pip list --user 2>/dev/null | sed -e '1,2d' | \
    while read i
        do
            _app=($i)
            app=${_app[0]}
            _app_info=$(pip show "$app" 2>/dev/null | sed -n '3 p')
            app_info=${_app_info#"Summary: "}
            echo "\"$app::$app_info\"" >> backup/default.pip.list.sh
            ProgressBar ${_start} ${_end}
            ((_start=_start+1))
    done
    echo ""
}

# @function backup_brew
# @description Backup the list of brew formulaes
function backup_brew {
    _start=1
    _end=$(brew leaves | wc -l)
    brew leaves | sed | \
    while read i
        do
            app=$i
            app_info=$(brew info "$app" 2>/dev/null | sed -n '2 p')
            echo "\"$app::$app_info\"" >> backup/default.brew.list.sh
            ProgressBar ${_start} ${_end}
            ((_start=_start+1))
    done
    echo ""
}

# @function backup_casks
# @description Backup the list of brew cask software
function backup_cask {
    _start=1
    _end=$(brew list --casks | wc -l)
    brew list --casks | sed | \
    while read i
        do
            app=$i
            app_description_line=$(brew info --cask "$app" 2>/dev/null | awk '/^==> Description/ { print NR;}')
            ((app_info_line=app_description_line+1))
            app_info=$(brew info --cask "$app" 2>/dev/null | sed -n "$app_info_line p")
            if [ "$app_info" = "None" ]; then
                echo "\"$app::\"" >> backup/default.cask.list.sh
            else
                echo "\"$app::$app_info\"" >> backup/default.cask.list.sh
            fi
            ProgressBar ${_start} ${_end}
            ((_start=_start+1))
    done
    echo ""
}

# @function backup_mas
# @description Backup the list of mas software
function backup_mas {
    _start=1
    _end=$(mas list | wc -l)
    mas list | sed | \
    while read i
        do
            _app=($i)
            app=${_app[0]}
            app_info=$(mas info "$app" 2>/dev/null | sed -n '1 p')
            echo "\"$app::$app_info\"" >> ./backup/default.mas.list.sh
            ProgressBar ${_start} ${_end}
            ((_start=_start+1))
    done
    echo ""
}

softwareList="brew cask mas npm pip"
software=($softwareList)

# Create the backup directory if doesn't exist silently
mkdir -p backup

printf "\n%s\n" "Backing up the machine list of installed $softwareList software"
for _software in "${software[@]}"; do
    printf "\n%s\n" "🗄️  Backing-up ${_software}"
    _list_name="./backup/default.$_software.list.sh"
    touch $_list_name
    cat >$_list_name <<EOL
# @Name: Default
# @List: ${_software}List
export ${_software}List=(

EOL
    backup_function="backup_$_software"
    $backup_function
    echo ")"  >> $_list_name
done;
