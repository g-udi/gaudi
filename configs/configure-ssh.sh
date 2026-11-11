#!/usr/bin/env bash
# shellcheck shell=bash

gaudi::log "Checking SSH configuration"

gaudi::has_ssh_identity() {
    local key=""

    for key in "$HOME"/.ssh/id_*.pub; do
        [[ -f "$key" ]] && return 0
    done

    # Keys served by an agent (1Password, Secretive, a hardware key) have no file
    if gaudi::command_exists ssh-add && ssh-add -l >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

if gaudi::has_ssh_identity; then
    gaudi::success "SSH key already available"
    return 0
fi

# Key generation asks for an email and a passphrase, so it needs a terminal
if ! gaudi::interactive; then
    gaudi::warn "No SSH key found and no terminal attached: skipping key generation"
    return 0
fi

gaudi::confirm "No SSH public key found. Generate an ed25519 key now?" "y" || return 0

EMAIL="${GAUDI_SSH_EMAIL:-}"
if [[ -z "$EMAIL" ]]; then
    printf "Email address for SSH key: "
    EMAIL="$(gaudi::read_email)" || {
        gaudi::warn "No email provided: skipping key generation"
        return 0
    }
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if ! ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519"; then
    gaudi::record_failure "SSH key generation"
    return 0
fi

if gaudi::command_exists ssh-add; then
    # Reuse the running agent (launchd provides one on macOS)
    [[ -n "${SSH_AUTH_SOCK:-}" ]] || eval "$(ssh-agent -s)" >/dev/null
    if [[ "${OS:-}" == "osx" ]]; then
        ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" >/dev/null 2>&1 \
            || ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1 || true
    else
        ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1 || true
    fi
fi

printf "\n%b\n" "${YELLOW:-}Add this public key to GitHub or any private Git host:${NC:-}"
cat "$HOME/.ssh/id_ed25519.pub"
printf "\n"
