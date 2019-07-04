#!/usr/bin/env bash

if [[ -d "/Applications/Visual Studio Code.app" ]]; then
    echo "Adding VS Code to the path so that you can do ... code 👾"
    sudo ln -s "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "/usr/bin/code"
fi