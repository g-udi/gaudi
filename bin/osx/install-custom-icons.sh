#!/usr/bin/env bash

read -p "Would you like to install the set of custom icons? [Y/N] " -n 1 </dev/tty
if [[ $REPLY =~ ^[Yy]$ ]]; then

    echo ""
    # Check if we have asdf plugins and languages to set
    for ICONS_LIST in $(find . -type f -iname osx-icons.list.sh); do
        . $ICONS_LIST
        for icon in "${iconsList[@]}"; do

            _icon="${icon%%::*}"
            _path="${icon#*::}"
            _application="$(echo $_path| cut -d'/' -f 3)"

            # Check if we do not have a custom path defined and try to extract the icon location
            if [[ "$_path" == "$_icon" ]]; then
                
                if [ -d "/Applications/$_icon.app" ]; then                
                    # Extract the icon name from the application name .. lets see if we can figure it out automtically
                    __iconName="$(defaults read /Applications/"$_icon".app/Contents/Info.plist CFBundleIconFile)"
                    __iconPath="/Applications/$_icon.app/Contents/Resources/${__iconName%".icns"}.icns"

                    printf "Changing the icon 🎨 for: ${RED}${_application%".app"}${NC}\n"
                    # Check if we have a custom path defined different from the default path .. lets always pick the custom one
                    if [[ "$_path" == "$_icon" ]]; then
                        cp "./lib/icons/$_icon.icns" "$__iconPath"
                    else
                        cp "./lib/icons/$_icon.icns" "$path"
                    fi;
                    touch "/Applications/${_application%".app"}.app"
                fi;
            else
                for __ICON in $(find . -type f -iname "$_icon.icns"); do
                    if [[ -f "$_path" ]]; then
                        printf "Changing the icon 🎨 for: ${RED}${_application%".app"}${NC}\n"
                        cp "$__ICON" "$_path"
                        touch "/Applications/${_application%".app"}.app"
                    fi
                done;
            fi;
        done;
    done;   
    sudo killall Finder && sudo killall Dock 
fi