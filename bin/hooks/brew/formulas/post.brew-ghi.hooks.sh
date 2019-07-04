#!/usr/bin/env bash

if command_exists ghi ; then
    read -p "⚙️  Configuring ghi ... What is your github username ? " GITHUB_USERNAME </dev/tty && ghi config --auth ${GITHUB_USERNAME} </dev/tty  
fi