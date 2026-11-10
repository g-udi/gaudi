#!/usr/bin/env bash
# shellcheck shell=bash

cat <<EOF

${YELLOW:-}Shell helpers${NC:-}

Gaudi can optionally install shell helper frameworks:

- gaudi-bash: Bash aliases, completions, themes, and helper commands.
- oh-my-zsh: Zsh framework for plugins and themes.

Detected shell: ${GAUDI_SETUP_SHELL:-unknown}

EOF

gaudi::install_gaudi_bash() {
    gaudi::confirm "Install gaudi-bash?" "n" || return 0
    gaudi::run_remote_script bash "https://raw.githubusercontent.com/g-udi/gaudi-bash/master/install.sh" -s --basic \
        || gaudi::record_failure "gaudi-bash installation"
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
    bash)
        gaudi::install_gaudi_bash
        gaudi::install_oh_my_zsh
        ;;
    zsh)
        gaudi::install_oh_my_zsh
        gaudi::install_gaudi_bash
        ;;
    *)
        gaudi::install_gaudi_bash
        gaudi::install_oh_my_zsh
        ;;
esac
