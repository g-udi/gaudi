#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

GAUDI="${GAUDI:-$HOME/.gaudi}"
GAUDI_REPO_URL="${GAUDI_REPO_URL:-https://github.com/g-udi/gaudi.git}"
export GAUDI

log() {
    printf "%s\n" "$*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_minimum_prerequisites() {
    case "$(uname -s 2>/dev/null || printf unknown)" in
        Darwin)
            if ! command_exists git; then
                if ! command_exists brew; then
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    if [[ -x /opt/homebrew/bin/brew ]]; then
                        eval "$(/opt/homebrew/bin/brew shellenv)"
                    elif [[ -x /usr/local/bin/brew ]]; then
                        eval "$(/usr/local/bin/brew shellenv)"
                    fi
                fi
                brew install git
            fi
            ;;
        Linux)
            if command_exists apt-get; then
                sudo apt-get update
                sudo apt-get install -y ca-certificates curl git
            elif ! command_exists git; then
                log "git is required. Install git and rerun this installer."
                exit 1
            fi
            ;;
        *)
            command_exists git || {
                log "git is required. Install git and rerun this installer."
                exit 1
            }
            ;;
    esac
}

install_or_update_repo() {
    if [[ -d "$GAUDI/.git" ]]; then
        log "Updating existing Gaudi checkout at $GAUDI"
        git -C "$GAUDI" fetch --depth=1 origin master
        git -C "$GAUDI" checkout master
        git -C "$GAUDI" pull --ff-only origin master
        return
    fi

    if [[ -e "$GAUDI" ]]; then
        log "Refusing to overwrite non-Git path: $GAUDI"
        log "Move it aside or set GAUDI to another install directory."
        exit 1
    fi

    umask g-w,o-w
    git clone --depth=1 "$GAUDI_REPO_URL" "$GAUDI"
}

install_minimum_prerequisites
install_or_update_repo
exec "$GAUDI/setup.sh" "$@"
