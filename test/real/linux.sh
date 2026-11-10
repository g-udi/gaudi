#!/usr/bin/env bash
# shellcheck shell=bash
# Real end-to-end run on Linux in a throwaway Docker container.
#
# Nothing is faked: the real package manager installs real packages, the real
# backup reads the real package database, and the restore reinstalls packages
# that were really removed. The container runs as root, like a fresh server
# (Debian's image has no sudo at all). It is deleted afterwards; the host is
# not touched.
#
#   test/real/linux.sh                 Debian
#   test/real/linux.sh fedora          Fedora
#   GAUDI_E2E_IMAGE=ubuntu:24.04 test/real/linux.sh debian
#
# Invoked without Docker available, it reports SKIP and exits 0.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"

if [[ "${1:-}" != "--inside" ]]; then
    DISTRO="${1:-debian}"
    case "$DISTRO" in
        debian) IMAGE="${GAUDI_E2E_IMAGE:-debian:bookworm-slim}" ;;
        fedora) IMAGE="${GAUDI_E2E_IMAGE:-fedora:latest}" ;;
        *) printf "Unknown distribution: %s (debian or fedora)\n" "$DISTRO" >&2; exit 64 ;;
    esac
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        printf "SKIP: Docker is not available, the real %s run was not executed\n" "$DISTRO"
        exit 0
    fi
    exec docker run --rm \
        -v "$ROOT_DIR:/src:ro" \
        -e DEBIAN_FRONTEND=noninteractive \
        "$IMAGE" bash /src/test/real/linux.sh --inside "$DISTRO"
fi

# ----------------------------------------------------------------------------------
# From here on we are root inside the container.
# ----------------------------------------------------------------------------------

DISTRO="$2"
case "$DISTRO" in
    debian)
        LIST_TYPE="apt"
        LIST_NAME="aptList"
        remove_packages() { apt-get remove -y -qq "$@" >/dev/null; }
        ;;
    fedora)
        LIST_TYPE="dnf"
        LIST_NAME="dnfList"
        remove_packages() { dnf remove -y -q "$@" >/dev/null; }
        ;;
esac

step() {
    printf "\n=== %s ===\n" "$*"
}

fail() {
    printf "REAL E2E FAILED: %s\n" "$*" >&2
    exit 1
}

have() {
    hash -r
    command -v "$1" >/dev/null 2>&1
}

# Debian's image has no sudo (Gaudi must run the commands directly as root);
# Fedora's has it (Gaudi goes through sudo). Both paths are exercised.
if command -v sudo >/dev/null 2>&1; then
    printf "Running as root, sudo is installed\n"
else
    printf "Running as root, without sudo\n"
fi
have tree && fail "tree is already installed: the image is not clean"
have jq && fail "jq is already installed: the image is not clean"

step "Install Gaudi from the mounted checkout"
export GAUDI="$HOME/.gaudi"
mkdir -p "$GAUDI"
cp -R /src/bin /src/lib /src/configs /src/setup.sh /src/backup.sh /src/check.sh /src/install.sh "$GAUDI/"

TEMPLATES="/tmp/templates"
mkdir -p "$TEMPLATES/lists" "$TEMPLATES/hooks" "$TEMPLATES/configs" "$TEMPLATES/dotfiles/.config/demo"
cat > "$TEMPLATES/lists/default.$LIST_TYPE.list.sh" <<LIST
# @Name: Real packages
# @Description: Two small tools installed with the real package manager
# @List: $LIST_NAME
$LIST_NAME=(
  "tree::Directory listing"
  "jq::JSON processor"
)
LIST
printf 'brew "hello"\n' > "$TEMPLATES/lists/core.Brewfile"
printf 'touch /tmp/pre-list-hook-ran\n' > "$TEMPLATES/hooks/pre.$LIST_TYPE.hooks.sh"
cat > "$TEMPLATES/configs/marker.configs.$DISTRO.sh" <<'CONFIG'
_info="Write a marker file"
_command() {
    touch /tmp/os-config-applied
}
CONFIG
printf 'demo = true\n' > "$TEMPLATES/dotfiles/.config/demo/settings.conf"
printf '.config/demo\n' > "$TEMPLATES/dotfiles.list"
export GAUDI_TEMPLATES_LOCATION="$TEMPLATES"

step "The templates pass gaudi check"
"$GAUDI/bin/gaudi" check "$TEMPLATES"

step "Full setup as root"
"$GAUDI/setup.sh" --yes --skip-ssh --skip-templates --skip-shell-helpers </dev/null
have git || fail "prerequisites did not install git"
have make || fail "prerequisites did not install the build tools"
have tree || fail "tree was not installed"
have jq || fail "jq was not installed"
[[ -f /tmp/pre-list-hook-ran ]] || fail "the pre.$LIST_TYPE hook did not run"
[[ -f /tmp/os-config-applied ]] || fail "the $DISTRO config was not applied"
[[ -f "$HOME/.config/demo/settings.conf" ]] || fail "the dotfile was not restored"
[[ -L "$HOME/.local/bin/gaudi" ]] || fail "the gaudi CLI was not linked"

step "The CLI works"
"$HOME/.local/bin/gaudi" doctor
"$HOME/.local/bin/gaudi" version >/dev/null

step "Back up the machine"
printf 'changed = on this machine\n' >> "$HOME/.config/demo/settings.conf"
"$HOME/.local/bin/gaudi" backup /tmp/backup
BACKUP_LIST="/tmp/backup/default.$LIST_TYPE.list.sh"
[[ -f "$BACKUP_LIST" ]] || fail "the backup did not write a $LIST_TYPE list"
grep -q '"tree"' "$BACKUP_LIST" || fail "the backup does not contain tree"
grep -q '"jq"' "$BACKUP_LIST" || fail "the backup does not contain jq"
grep -q 'changed = on this machine' /tmp/backup/dotfiles/.config/demo/settings.conf || fail "the backup does not contain the changed dotfile"
printf "The backup holds %s packages\n" "$(grep -c '^  "' "$BACKUP_LIST")"

step "The backup itself passes gaudi check"
"$HOME/.local/bin/gaudi" check /tmp/backup

step "Lose the software and the dotfile"
remove_packages tree jq
rm -rf "$HOME/.config/demo"
have tree && fail "tree is still there after removal"
have jq && fail "jq is still there after removal"

step "Restore from the backup"
GAUDI_TEMPLATES_LOCATION="/tmp/backup" "$GAUDI/setup.sh" --yes --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-configs </dev/null
have tree || fail "tree was not restored"
have jq || fail "jq was not restored"
printf '{"restored": true}\n' | jq -e '.restored' >/dev/null || fail "the restored jq does not work"
grep -q 'changed = on this machine' "$HOME/.config/demo/settings.conf" || fail "the dotfile was not restored from the backup"

step "A second backup matches the first"
"$HOME/.local/bin/gaudi" backup /tmp/backup-after-restore
# Compared in Bash: minimal images (Fedora) do not ship diff
[[ "$(cat "$BACKUP_LIST")" == "$(cat "/tmp/backup-after-restore/default.$LIST_TYPE.list.sh")" ]] \
    || fail "the backup changed after the restore"

printf "\nREAL E2E OK (%s)\n" "$(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
