#!/usr/bin/env bash

if [ ! -f "$HOME/.todoist.config.json" ]; then

    echo "Setting up Todist ✓"

    read -p "What is your Todoist API access token: " TOKEN;
    read -p "Would you like to colorise output (default: false) ? [true/false] " COLORIZE;

    echo "{\"token\": \"${TOKEN}\", \"color\": \"${COLORIZE}\"}" > "$HOME/.todoist.config.json"
fi