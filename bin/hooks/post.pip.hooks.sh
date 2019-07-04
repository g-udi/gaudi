#!/usr/bin/env bash

if command_exists aws && command_exists aws_completer; then
    echo "Making sure we enable the CLI completion for AWS 🎹"
    complete -C `which aws_completer` aws
fi