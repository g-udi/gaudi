#!/usr/bin/env bash
# shellcheck shell=bash
# Real end-to-end run on macOS with the real Homebrew.
#
# This installs and uninstalls a real formula, so it only runs when asked to:
# in CI (a throwaway runner), or locally with GAUDI_E2E_REAL_MACOS=1.
#
# It installs the tiny `hello` formula from a Brewfile, backs the machine up,
# uninstalls `hello`, restores from the backup and checks `hello` is back.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
FORMULA="${GAUDI_E2E_FORMULA:-hello}"

if [[ "${GAUDI_E2E_REAL_MACOS:-0}" != "1" ]]; then
    printf "SKIP: set GAUDI_E2E_REAL_MACOS=1 to install and uninstall the real '%s' formula\n" "$FORMULA"
    exit 0
fi

step() {
    printf "\n=== %s ===\n" "$*"
}

fail() {
    printf "REAL E2E FAILED: %s\n" "$*" >&2
    exit 1
}

installed() {
    brew list --versions "$FORMULA" >/dev/null 2>&1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "this script is for macOS"
command -v brew >/dev/null 2>&1 || fail "Homebrew is required"
installed && fail "$FORMULA is already installed: pick another formula with GAUDI_E2E_FORMULA"

WORK="$(mktemp -d)"
export HOME_BACKUP="$HOME"
export GAUDI_BIN_DIR="$WORK/bin"
export GAUDI_SETUP_PROFILE="$WORK/profile"
export GAUDI_BUNDLE_NO_UPGRADE="true"
export HOMEBREW_NO_AUTO_UPDATE=1
SKIP="--yes --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-configs --skip-cleanup"

cleanup() {
    brew uninstall --ignore-dependencies "$FORMULA" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

step "Install from a Brewfile"
mkdir -p "$WORK/templates/lists"
printf '# @Name: Real formula\nbrew "%s"\n' "$FORMULA" > "$WORK/templates/lists/core.Brewfile"
# shellcheck disable=SC2086
GAUDI_TEMPLATES_LOCATION="$WORK/templates" "$ROOT_DIR/setup.sh" $SKIP </dev/null
installed || fail "$FORMULA was not installed"
[[ -L "$WORK/bin/gaudi" ]] || fail "the gaudi CLI was not linked"

step "Back up the machine"
"$WORK/bin/gaudi" backup "$WORK/backup"
grep -q "^brew \"$FORMULA\"" "$WORK/backup/Brewfile" || fail "the backup does not contain $FORMULA"
printf "The backup holds %s entries\n" "$(grep -c '^[a-z]* "' "$WORK/backup/Brewfile")"

step "Lose the software"
brew uninstall --ignore-dependencies "$FORMULA"
installed && fail "$FORMULA is still installed after removal"

step "Restore from the backup"
mkdir -p "$WORK/restore/lists"
cp "$WORK/backup/Brewfile" "$WORK/restore/lists/Brewfile"
# shellcheck disable=SC2086
GAUDI_TEMPLATES_LOCATION="$WORK/restore" "$ROOT_DIR/setup.sh" $SKIP </dev/null
installed || fail "$FORMULA was not restored"

printf "\nREAL E2E OK (macOS %s)\n" "$(sw_vers -productVersion)"
