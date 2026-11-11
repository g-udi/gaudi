#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

GAUDI="${GAUDI:-$HOME/.gaudi}"
GAUDI_REPO_URL="${GAUDI_REPO_URL:-https://github.com/g-udi/gaudi.git}"
GAUDI_BRANCH="${GAUDI_BRANCH:-main}"
export GAUDI

log() {
    printf "%s\n" "$*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# sudo when it exists, directly when already root (minimal images have no sudo)
as_root() {
    if command_exists sudo; then
        sudo "$@"
    elif [[ "$(id -u 2>/dev/null || printf 1)" == "0" ]]; then
        "$@"
    else
        log "This step needs root: install sudo or run this installer as root."
        exit 1
    fi
}

# Homebrew is not on PATH right after it is installed.
# GAUDI_BREW_BIN_DIRS (colon-separated) overrides where to look for it.
load_brew() {
    local dirs="${GAUDI_BREW_BIN_DIRS-/opt/homebrew/bin:/usr/local/bin}"
    local dir=""
    local old_ifs="$IFS"

    IFS=":"
    for dir in $dirs; do
        if [[ -n "$dir" && -x "$dir/brew" ]]; then
            IFS="$old_ifs"
            eval "$("$dir/brew" shellenv)"
            return 0
        fi
    done
    IFS="$old_ifs"
}

install_minimum_prerequisites() {
    case "$(uname -s 2>/dev/null || printf unknown)" in
        Darwin)
            # /usr/bin/git exists on a fresh Mac but is only a stub until the
            # Command Line Tools are installed, so test for the tools instead.
            if ! xcode-select -p >/dev/null 2>&1; then
                load_brew
                if command_exists brew; then
                    log "Xcode Command Line Tools are missing. Finish the installer that opens, then rerun this command."
                    xcode-select --install || true
                    exit 1
                fi
                # The Homebrew installer installs the Command Line Tools itself
                homebrew_installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                    log "Could not download the Homebrew installer. Check the network and rerun this command."
                    exit 1
                }
                /bin/bash -c "$homebrew_installer"
                load_brew
            fi
            if ! command_exists git; then
                load_brew
                brew install git
            fi
            ;;
        Linux)
            if ! command_exists git || ! command_exists curl; then
                if command_exists apt-get; then
                    as_root apt-get update
                    as_root apt-get install -y ca-certificates curl git
                elif command_exists dnf; then
                    # curl is only added when missing: Fedora images ship
                    # curl-minimal, which conflicts with the full package
                    if command_exists curl; then
                        as_root dnf install -y git
                    else
                        as_root dnf install -y curl git
                    fi
                elif command_exists pacman; then
                    as_root pacman -Sy --noconfirm --needed curl git
                elif command_exists zypper; then
                    as_root zypper --non-interactive install curl git
                else
                    log "git and curl are required. Install them and rerun this installer."
                    exit 1
                fi
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
        git -C "$GAUDI" fetch --depth=1 origin "$GAUDI_BRANCH"
        # Only edits to Gaudi's own files block an update. Untracked files are
        # left alone: other tools keep their data next to Gaudi (widgets, the
        # helper), and a checkout that merely contains them must still update.
        if [[ -n "$(git -C "$GAUDI" status --porcelain --untracked-files=no)" ]]; then
            log "Local changes found in $GAUDI: keeping the installed version."
            log "Commit or discard them and rerun to update."
            return
        fi
        # The checkout is shallow, so the new commit has no shared history to
        # fast-forward along: move the branch to what was just fetched instead.
        git -C "$GAUDI" checkout -q -B "$GAUDI_BRANCH" FETCH_HEAD
        return
    fi

    if [[ -e "$GAUDI" ]]; then
        log "Refusing to overwrite non-Git path: $GAUDI"
        log "Move it aside or set GAUDI to another install directory."
        exit 1
    fi

    umask g-w,o-w
    git clone --depth=1 --branch "$GAUDI_BRANCH" "$GAUDI_REPO_URL" "$GAUDI"
}

install_minimum_prerequisites
install_or_update_repo
exec "$GAUDI/setup.sh" "$@"
