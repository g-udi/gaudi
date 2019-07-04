#!/usr/bin/env bash

echo "Checking if gopath variable is set .. the home 🏡 for all of your golang applications"
[ -z "$GOPATH" ] && mkdir -p "$HOME/Applications/Go" && echo "Setting the GOPATH to $HOME/Applications/Go" && export GOPATH="$HOME/Applications/Go"
