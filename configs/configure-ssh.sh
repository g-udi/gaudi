#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Checking SSH configuration"

if [[ -f "$HOME/.ssh/id_ed25519.pub" || -f "$HOME/.ssh/id_rsa.pub" ]]; then
    gaudi::success "SSH key already exists"
    return 0
fi

gaudi::confirm "No SSH public key found. Generate an ed25519 key now?" "y" || return 0

printf "Email address for SSH key: "
EMAIL="$(read_email)"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519"

if gaudi::command_exists ssh-agent && gaudi::command_exists ssh-add; then
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1 || true
fi

printf "\n%b\n" "${YELLOW:-}Add this public key to GitHub or any private Git host:${NC:-}"
cat "$HOME/.ssh/id_ed25519.pub"
printf "\n"
