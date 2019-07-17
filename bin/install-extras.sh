#!/usr/bin/env bash

read -p  "Do you have any extra scripts in the 'extras' folder?  " -n 1

if [[ $REPLY =~ ^[yY]$ ]]; then
    if [ -d "$SOURCE_LOCATION/gaudi-files/extras" ]; then
        for shfile in $SOURCE_LOCATION/gaudi-files/extras/*.sh
        do
            chmod +x $shfile
            $shfile
        done
    fi

fi;
