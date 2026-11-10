#!/usr/bin/env bats
# lib/install-shell-helpers.sh, lib/osx/cleanup.sh and lib/debian/cleanup.sh

load ../helper

setup() {
    gaudi_sandbox darwin
}

helpers_step() {
    step lib/install-shell-helpers.sh
}

GAUDI_BASH_URL="https://raw.githubusercontent.com/g-udi/gaudi-bash/master/install.sh"
OH_MY_ZSH_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# --- shell helpers -----------------------------------------------------------------

@test "shell helpers: the detected shell is shown" {
    export SHELL="/bin/bash"
    run helpers_step
    assert_success
    assert_output_contains "Detected shell: bash"
}

@test "shell helpers: nothing is installed by default" {
    run helpers_step
    assert_success
    assert_output_contains "Do you want to install shell helpers? [y/N]"
    refute_called "curl"
}

@test "shell helpers: --yes installs gaudi-bash and oh-my-zsh" {
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_success
    assert_called "curl -fsSL $GAUDI_BASH_URL"
    assert_called "curl -fsSL $OH_MY_ZSH_URL"
    assert_file_exists "$HOME/.gaudi_bash"
    assert_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: gaudi-bash is installed in basic mode" {
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_called "gaudi-bash-installer --basic"
}

@test "shell helpers: oh-my-zsh is installed unattended without switching shell or replacing .zshrc" {
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_called "oh-my-zsh-installer --unattended RUNZSH=no CHSH=no KEEP_ZSHRC=yes"
}

@test "shell helpers: an existing oh-my-zsh is not reinstalled" {
    mkdir -p "$HOME/.oh-my-zsh"
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_success
    assert_output_contains "oh-my-zsh is already installed"
    refute_called "curl -fsSL $OH_MY_ZSH_URL"
    assert_called "curl -fsSL $GAUDI_BASH_URL"
}

@test "shell helpers: zsh users are offered oh-my-zsh first" {
    export SHELL="/bin/zsh"
    interactive
    run helpers_step <<< "ynn"
    assert_success
    [[ "$output" == *"Install oh-my-zsh?"*"Install gaudi-bash?"* ]]
    refute_called "curl"
}

@test "shell helpers: bash users are offered gaudi-bash first" {
    export SHELL="/bin/bash"
    interactive
    run helpers_step <<< "ynn"
    assert_success
    [[ "$output" == *"Install gaudi-bash?"*"Install oh-my-zsh?"* ]]
}

@test "shell helpers: other shells are offered gaudi-bash first" {
    export SHELL="/usr/bin/fish"
    interactive
    run helpers_step <<< "ynn"
    assert_success
    [[ "$output" == *"Install gaudi-bash?"*"Install oh-my-zsh?"* ]]
}

@test "shell helpers: each helper can be chosen on its own" {
    export SHELL="/bin/zsh"
    interactive
    # helpers: y, oh-my-zsh: n, gaudi-bash: y
    run helpers_step <<< "yny"
    assert_success
    assert_file_exists "$HOME/.gaudi_bash"
    refute_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: failed downloads are recorded and do not stop the other helper" {
    export GAUDI_ASSUME_YES="true" FAKE_CURL_FAIL=1
    run helpers_step
    assert_failure 1
    assert_output_contains "gaudi-bash installation"
    assert_output_contains "oh-my-zsh installation"
    assert_output_contains "2 step(s) failed"
}

# --- cleanup -------------------------------------------------------------------------

@test "macOS cleanup runs brew cleanup" {
    run step lib/osx/cleanup.sh
    assert_success
    assert_called "brew cleanup -s"
}

@test "macOS cleanup without Homebrew is a warning" {
    remove_tool brew
    run step lib/osx/cleanup.sh
    assert_success
    assert_output_contains "Skipping cleanup: brew is not installed"
}

@test "macOS cleanup records a failing brew cleanup" {
    export FAKE_BREW_CLEANUP_FAIL=1
    run step lib/osx/cleanup.sh
    assert_failure 1
    assert_output_contains "brew cleanup"
}

@test "Debian cleanup removes unused packages and clears the apt cache" {
    gaudi_sandbox debian
    run step lib/debian/cleanup.sh
    assert_success
    assert_called "sudo apt-get autoremove -y"
    assert_called "sudo apt-get clean"
}

@test "Debian cleanup records failures and still runs both commands" {
    gaudi_sandbox debian
    export FAKE_APT_CLEAN_FAIL=1
    run step lib/debian/cleanup.sh
    assert_failure 1
    assert_called "apt-get autoremove -y"
    assert_called "apt-get clean"
    assert_output_contains "2 step(s) failed"
}
