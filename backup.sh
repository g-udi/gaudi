#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/colors.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/helpers.sh"
# shellcheck source=/dev/null
source "$SOURCE_LOCATION/bin/commands.sh"

BACKUP_DIR="${1:-$PWD/backup}"
mkdir -p "$BACKUP_DIR"

write_header() {
    local file="$1"
    local name="$2"
    local list_name="$3"

    cat > "$file" <<EOF
# @Name: $name
# @List: $list_name
export $list_name=(

EOF
}

write_footer() {
    printf ")\n" >> "$1"
}

append_item() {
    local file="$1"
    local package_name="$2"
    local description="${3:-}"
    local safe_package=""
    local safe_description=""

    safe_package="${package_name//\\/\\\\}"
    safe_package="${safe_package//\"/\\\"}"
    safe_description="${description//\\/\\\\}"
    safe_description="${safe_description//\"/\\\"}"

    printf '  "%s::%s"\n' "$safe_package" "$safe_description" >> "$file"
}

backup_brew() {
    local file="$BACKUP_DIR/default.brew.list.sh"
    local package_name=""

    write_header "$file" "Default" "brewList"
    if gaudi::command_exists brew; then
        while IFS= read -r package_name; do
            [[ -n "$package_name" ]] || continue
            append_item "$file" "$package_name" "$(brew desc --eval-all "$package_name" 2>/dev/null | sed 's/^[^:]*: //')"
        done < <(brew leaves 2>/dev/null)
    else
        gaudi::warn "Skipping Homebrew backup: brew is not installed"
    fi
    write_footer "$file"
}

backup_cask() {
    local file="$BACKUP_DIR/default.cask.list.sh"
    local package_name=""

    write_header "$file" "Default" "caskList"
    if gaudi::command_exists brew; then
        while IFS= read -r package_name; do
            [[ -n "$package_name" ]] || continue
            append_item "$file" "$package_name" "$(brew info --cask "$package_name" 2>/dev/null | awk '/^==> Description/{getline; print; exit}')"
        done < <(brew list --cask 2>/dev/null)
    else
        gaudi::warn "Skipping cask backup: brew is not installed"
    fi
    write_footer "$file"
}

backup_mas() {
    local file="$BACKUP_DIR/default.mas.list.sh"
    local app_id=""
    local app_name=""

    write_header "$file" "Default" "masList"
    if gaudi::command_exists mas; then
        while IFS= read -r app_id app_name; do
            [[ -n "$app_id" ]] || continue
            append_item "$file" "$app_id" "$app_name"
        done < <(mas list 2>/dev/null)
    else
        gaudi::warn "Skipping Mac App Store backup: mas is not installed"
    fi
    write_footer "$file"
}

backup_npm() {
    local file="$BACKUP_DIR/default.npm.list.sh"
    local package_path=""
    local package_name=""

    write_header "$file" "Default" "npmList"
    if gaudi::command_exists npm; then
        while IFS= read -r package_path; do
            [[ -n "$package_path" ]] || continue
            package_name="${package_path##*/}"
            if [[ "$(basename "$(dirname "$package_path")")" == @* ]]; then
                package_name="$(basename "$(dirname "$package_path")")/$package_name"
            fi
            append_item "$file" "$package_name"
        done < <(npm list -g --depth=0 --parseable 2>/dev/null | sed '1d')
    else
        gaudi::warn "Skipping npm backup: npm is not installed"
    fi
    write_footer "$file"
}

backup_pip() {
    local file="$BACKUP_DIR/default.pip.list.sh"
    local package_name=""

    write_header "$file" "Default" "pipList"
    if gaudi::command_exists python3; then
        while IFS='=' read -r package_name _; do
            [[ -n "$package_name" ]] || continue
            append_item "$file" "$package_name"
        done < <(python3 -m pip list --user --format=freeze 2>/dev/null || true)
    else
        gaudi::warn "Skipping pip backup: python3 is not installed"
    fi
    write_footer "$file"
}

backup_apt() {
    local file="$BACKUP_DIR/default.apt-get.sh"
    local package_name=""

    write_header "$file" "Default" "aptList"
    if gaudi::command_exists dpkg-query; then
        while IFS= read -r package_name; do
            [[ -n "$package_name" ]] || continue
            append_item "$file" "$package_name"
        done < <(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null)
    fi
    write_footer "$file"
}

gaudi::log "Writing backup lists to $BACKUP_DIR"

for manager in ${GAUDI_BACKUP_MANAGERS:-brew cask mas npm pip apt}; do
    case "$manager" in
        brew|cask|mas|npm|pip|apt)
            "backup_$manager"
            ;;
        *)
            gaudi::warn "Unknown backup manager: $manager"
            ;;
    esac
done

gaudi::success "Backup complete"
