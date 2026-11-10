#!/usr/bin/env bash
# shellcheck shell=bash
# Real end-to-end run on Debian in a throwaway Docker container.
#
# Nothing is faked: real apt installs real packages, the real backup reads the
# real package database, and the restore reinstalls packages that were really
# removed. The container is deleted afterwards; the host is not touched.
#
#   test/real/debian.sh            run it (needs Docker)
#   GAUDI_E2E_IMAGE=ubuntu:24.04 test/real/debian.sh
#
# Invoked without Docker available, it reports SKIP and exits 0.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
IMAGE="${GAUDI_E2E_IMAGE:-debian:bookworm-slim}"

if [[ "${1:-}" != "--inside" ]]; then
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        printf "SKIP: Docker is not available, the real Debian run was not executed\n"
        exit 0
    fi
    exec docker run --rm \
        -v "$ROOT_DIR:/src:ro" \
        -e DEBIAN_FRONTEND=noninteractive \
        "$IMAGE" bash /src/test/real/debian.sh --inside
fi

# ----------------------------------------------------------------------------------
# From here on we are root inside the container.
# ----------------------------------------------------------------------------------

step() {
    printf "\n=== %s ===\n" "$*"
}

fail() {
    printf "REAL E2E FAILED: %s\n" "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

step "Prepare the container (Gaudi expects sudo to exist)"
apt-get update -qq
apt-get install -y -qq sudo >/dev/null

step "Install Gaudi from the mounted checkout"
export GAUDI="$HOME/.gaudi"
mkdir -p "$GAUDI"
cp -R /src/bin /src/lib /src/configs /src/setup.sh /src/backup.sh /src/install.sh "$GAUDI/"

TEMPLATES="/tmp/templates"
mkdir -p "$TEMPLATES/lists" "$TEMPLATES/hooks" "$TEMPLATES/configs"
cat > "$TEMPLATES/lists/default.apt.list.sh" <<'EOF'
# @Name: Real packages
# @Description: Two small tools installed with the real apt
# @List: aptList
aptList=(
  "tree::Directory listing"
  "jq::JSON processor"
)
EOF
printf 'brew "hello"\n' > "$TEMPLATES/lists/core.Brewfile"
printf 'touch /tmp/pre-apt-hook-ran\n' > "$TEMPLATES/hooks/pre.apt.hooks.sh"
cat > "$TEMPLATES/configs/marker.configs.debian.sh" <<'EOF'
_info="Write a marker file"
_command() {
    touch /tmp/debian-config-applied
}
EOF
export GAUDI_TEMPLATES_LOCATION="$TEMPLATES"

have tree && fail "tree is already installed: the image is not clean"
have jq && fail "jq is already installed: the image is not clean"

step "Stage 1: prerequisites with the real apt (Homebrew declined by default)"
"$GAUDI/setup.sh" --skip-ssh --skip-templates --skip-shell-helpers --skip-software --skip-configs --skip-cleanup </dev/null
have git || fail "prerequisites did not install git"
have make || fail "prerequisites did not install build-essential"
[[ -L "$HOME/.local/bin/gaudi" ]] || fail "the gaudi CLI was not linked"

step "Stage 2: software, configs and cleanup"
"$GAUDI/setup.sh" --yes --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers </dev/null
have tree || fail "tree was not installed"
have jq || fail "jq was not installed"
[[ -f /tmp/pre-apt-hook-ran ]] || fail "the pre.apt hook did not run"
[[ -f /tmp/debian-config-applied ]] || fail "the Debian config was not applied"

step "The CLI works"
"$HOME/.local/bin/gaudi" doctor
"$HOME/.local/bin/gaudi" version >/dev/null

step "Back up the machine"
"$HOME/.local/bin/gaudi" backup /tmp/backup
BACKUP_LIST="/tmp/backup/default.apt.list.sh"
[[ -f "$BACKUP_LIST" ]] || fail "the backup did not write an apt list"
grep -q '"tree"' "$BACKUP_LIST" || fail "the backup does not contain tree"
grep -q '"jq"' "$BACKUP_LIST" || fail "the backup does not contain jq"
printf "The backup holds %s packages\n" "$(grep -c '^  "' "$BACKUP_LIST")"

step "Lose the software"
apt-get remove -y -qq tree jq >/dev/null
hash -r
have tree && fail "tree is still there after removal"
have jq && fail "jq is still there after removal"

step "Restore from the backup"
RESTORE="/tmp/restore-templates"
mkdir -p "$RESTORE/lists"
cp "$BACKUP_LIST" "$RESTORE/lists/"
GAUDI_TEMPLATES_LOCATION="$RESTORE" "$GAUDI/setup.sh" --yes --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-configs </dev/null
hash -r
have tree || fail "tree was not restored"
have jq || fail "jq was not restored"
printf '{"restored": true}\n' | jq -e '.restored' >/dev/null || fail "the restored jq does not work"

step "A second backup matches the first"
"$HOME/.local/bin/gaudi" backup /tmp/backup-after-restore
diff "$BACKUP_LIST" /tmp/backup-after-restore/default.apt.list.sh || fail "the backup changed after the restore"

printf "\nREAL E2E OK (%s)\n" "$(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
