#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_HELPER_REPO_URL="${GAUDI_HELPER_REPO_URL:-https://github.com/g-udi/gaudi-shell.git}"

cat <<EOF

${YELLOW:-}Shell helpers${NC:-}

Gaudi can optionally install shell helper frameworks:

- gaudi-shell: aliases, plugins, completions and themes for Bash and Zsh.
- oh-my-zsh: Zsh framework for plugins and themes.

Detected shell: ${GAUDI_SETUP_SHELL:-unknown}

EOF

# gaudi-shell is installed the way its README says: clone, then run its setup.
gaudi::install_gaudi_shell() {
    local target="$HOME/.gaudi-shell"
    local -a setup_args=(--silent)

    case "${GAUDI_SETUP_SHELL:-}" in
        bash|zsh)
            setup_args+=(--shell "$GAUDI_SETUP_SHELL")
            ;;
        *)
            gaudi::log "gaudi-shell supports Bash and Zsh: not offered for ${GAUDI_SETUP_SHELL:-this shell}"
            return 0
            ;;
    esac

    gaudi::confirm "Install gaudi-shell?" "n" || return 0

    if [[ -d "$target" ]]; then
        gaudi::success "gaudi-shell is already installed"
        return 0
    fi

    if ! git clone --depth=1 "$GAUDI_HELPER_REPO_URL" "$target"; then
        gaudi::record_failure "gaudi-shell installation (clone)"
        return 0
    fi

    "$target/setup.sh" "${setup_args[@]}" || gaudi::record_failure "gaudi-shell installation (setup)"
}

gaudi::install_oh_my_zsh() {
    gaudi::confirm "Install oh-my-zsh?" "n" || return 0

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        gaudi::success "oh-my-zsh is already installed"
        return 0
    fi

    (
        export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
        gaudi::run_remote_script sh "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "" --unattended
    ) || gaudi::record_failure "oh-my-zsh installation"
}

gaudi::confirm "Do you want to install shell helpers?" "n" || return 0

case "${GAUDI_SETUP_SHELL:-}" in
    zsh)
        gaudi::install_oh_my_zsh
        gaudi::install_gaudi_shell
        ;;
    *)
        gaudi::install_gaudi_shell
        gaudi::install_oh_my_zsh
        ;;
esac
