#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

find "$ROOT_DIR" -name '*.sh' -type f -print0 | xargs -0 /bin/bash -n
/bin/bash -n "$ROOT_DIR/bin/gaudi"

if command -v shellcheck >/dev/null 2>&1; then
    find "$ROOT_DIR" -name '*.sh' -type f -print0 | xargs -0 shellcheck -x -S warning
    shellcheck -x -S warning "$ROOT_DIR/bin/gaudi"
fi

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT

HOME="$tmp_home" SHELL="/bin/zsh" GAUDI="$ROOT_DIR" "$ROOT_DIR/bin/gaudi" doctor >/dev/null
HOME="$tmp_home" SHELL="/bin/fish" GAUDI_TARGET_SHELL="fish" GAUDI="$ROOT_DIR" "$ROOT_DIR/setup.sh" \
    --yes \
    --skip-prereqs \
    --skip-templates \
    --skip-software \
    --skip-configs \
    --skip-shell-helpers \
    --skip-ssh \
    --skip-cleanup >/dev/null

[[ -L "$tmp_home/.local/bin/gaudi" ]]
grep -Fq "set -gx PATH \"$tmp_home/.local/bin\"" "$tmp_home/.config/fish/config.fish"

templates_dir="$tmp_home/templates"
fakebin="$tmp_home/fakebin"
mkdir -p "$templates_dir/lists" "$templates_dir/hooks" "$fakebin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/apt-get"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/brew"
chmod +x "$fakebin/apt-get" "$fakebin/brew"

cat > "$templates_dir/lists/default.apt-get.sh" <<'APT'
# @Name: Apt Default
# @Description: Debian packages
# @List: aptList
aptList=(
  "curl::transfer tool"
)
APT

cat > "$templates_dir/lists/default.brew.list.sh" <<'BREW'
# @Name: Brew Default
# @List: brewList
brewList=(
  "jq::json tool"
)
BREW

cat > "$templates_dir/hooks/pre.apt.hooks.sh" <<'HOOK'
printf 'pre-apt-hook\n'
HOOK

GAUDI="$ROOT_DIR" \
SOURCE_LOCATION="$ROOT_DIR" \
GAUDI_TEMPLATES_LOCATION="$templates_dir" \
GAUDI_ASSUME_YES=true \
GAUDI_DRY_RUN=true \
OS=debian \
PATH="$fakebin:$PATH" \
/bin/bash --noprofile --norc <<'BASH' > "$tmp_home/install-software.out"
source "$SOURCE_LOCATION/bin/colors.sh"
source "$SOURCE_LOCATION/bin/helpers.sh"
source "$SOURCE_LOCATION/bin/commands.sh"
source "$SOURCE_LOCATION/bin/installer.sh"
source "$SOURCE_LOCATION/lib/install-software.sh"
BASH

grep -Fq "pre-apt-hook" "$tmp_home/install-software.out"
grep -Fq "DRY RUN: sudo apt-get install -y curl" "$tmp_home/install-software.out"
grep -Fq "DRY RUN: brew_install_or_upgrade jq" "$tmp_home/install-software.out"

GAUDI_BACKUP_MANAGERS=apt GAUDI="$ROOT_DIR" "$ROOT_DIR/bin/gaudi" backup "$tmp_home/backup" >/dev/null
[[ -f "$tmp_home/backup/default.apt-get.sh" ]]

printf "smoke ok\n"
