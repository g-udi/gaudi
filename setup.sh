#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090
set -euo pipefail

SOURCE_LOCATION="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
export SOURCE_LOCATION
GAUDI="${GAUDI:-$SOURCE_LOCATION}"
export GAUDI

GAUDI_ASSUME_YES="${GAUDI_ASSUME_YES:-false}"
GAUDI_SKIP_SOFTWARE="${GAUDI_SKIP_SOFTWARE:-false}"
GAUDI_SKIP_CONFIGS="${GAUDI_SKIP_CONFIGS:-false}"
GAUDI_SKIP_SHELL_HELPERS="${GAUDI_SKIP_SHELL_HELPERS:-false}"
GAUDI_SKIP_SSH="${GAUDI_SKIP_SSH:-false}"
GAUDI_SKIP_PREREQS="${GAUDI_SKIP_PREREQS:-false}"
GAUDI_SKIP_TEMPLATES="${GAUDI_SKIP_TEMPLATES:-false}"
GAUDI_SKIP_CLEANUP="${GAUDI_SKIP_CLEANUP:-false}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            GAUDI_ASSUME_YES="true"
            ;;
        --skip-software)
            GAUDI_SKIP_SOFTWARE="true"
            ;;
        --skip-configs)
            GAUDI_SKIP_CONFIGS="true"
            ;;
        --skip-shell-helpers)
            GAUDI_SKIP_SHELL_HELPERS="true"
            ;;
        --skip-ssh)
            GAUDI_SKIP_SSH="true"
            ;;
        --skip-prereqs)
            GAUDI_SKIP_PREREQS="true"
            ;;
        --skip-templates)
            GAUDI_SKIP_TEMPLATES="true"
            ;;
        --skip-cleanup)
            GAUDI_SKIP_CLEANUP="true"
            ;;
        --help|-h)
            cat <<'USAGE'
Usage: setup.sh [--yes] [--skip-prereqs] [--skip-templates] [--skip-software] [--skip-configs] [--skip-shell-helpers] [--skip-ssh] [--skip-cleanup]
USAGE
            exit 0
            ;;
        *)
            printf "Unknown option: %s\n" "$1" >&2
            exit 64
            ;;
    esac
    shift
done

export GAUDI_ASSUME_YES GAUDI_SKIP_SOFTWARE GAUDI_SKIP_CONFIGS GAUDI_SKIP_SHELL_HELPERS GAUDI_SKIP_SSH GAUDI_SKIP_PREREQS GAUDI_SKIP_TEMPLATES GAUDI_SKIP_CLEANUP

for config in "$SOURCE_LOCATION"/bin/{colors,helpers,commands,installer}.sh; do
    # shellcheck source=/dev/null
    source "$config"
done

cat <<'EOF'

   ▄██████▄     ▄████████ ███    █▄  ████████▄   ▄█
  ███    ███   ███    ███ ███    ███ ███   ▀███ ███
  ███    █▀    ███    ███ ███    ███ ███    ███ ███▌
 ▄███          ███    ███ ███    ███ ███    ███ ███▌
▀▀███ ████▄  ▀███████████ ███    ███ ███    ███ ███▌
  ███    ███   ███    ███ ███    ███ ███    ███ ███
  ███    ███   ███    ███ ███    ███ ███   ▄███ ███
  ████████▀    ███    █▀  ████████▀  ████████▀  █▀

EOF

get_os
get_shell_type

gaudi::log "Install root: $SOURCE_LOCATION"
gaudi::log "Detected OS: ${OS:-unknown}"
gaudi::log "Detected shell: ${GAUDI_SHELL:-unknown}"
gaudi::log "Shell profile: ${GAUDI_SHELL_PROFILE:-unknown}"

gaudi::supported_os || {
    gaudi::error "Gaudi currently automates macOS and Debian/Ubuntu. Detected: ${OS:-unknown}"
    exit 1
}

gaudi::install_cli

if [[ "$GAUDI_SKIP_PREREQS" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/lib/${OS}/install-pre-requisits.sh"
fi

if [[ "$GAUDI_SKIP_SSH" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/configs/configure-ssh.sh"
fi

if [[ "$GAUDI_SKIP_TEMPLATES" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/configs/configure-gaudi.sh"
fi

if [[ "$GAUDI_SKIP_SHELL_HELPERS" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/lib/install-shell-helpers.sh"
fi

if [[ "$GAUDI_SKIP_SOFTWARE" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/lib/install-software.sh"
fi

if [[ "$GAUDI_SKIP_CONFIGS" != "true" ]]; then
    gaudi::source_if_exists "$SOURCE_LOCATION/lib/${OS}/configure.sh"
fi

if [[ "$GAUDI_SKIP_CLEANUP" != "true" ]] && gaudi::confirm "Run package-manager cleanup now?" "n"; then
    gaudi::source_if_exists "$SOURCE_LOCATION/lib/${OS}/cleanup.sh"
fi

gaudi::success "Gaudi setup finished"
