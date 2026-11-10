#!/usr/bin/env bats
# lib/install-shell-helpers.sh, lib/osx/cleanup.sh and lib/debian/cleanup.sh

load ../helper

setup() {
    gaudi_sandbox darwin
}

helpers_step() {
    step lib/install-shell-helpers.sh
}

OH_MY_ZSH_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# --- shell helpers -----------------------------------------------------------------

# A stand-in for the gaudi-shell repository: its setup.sh records how it was run
helper_repository() {
    local repo="$SANDBOX/remotes/gaudi-shell"

    mkdir -p "$repo"
    printf '#!/usr/bin/env bash\nprintf "gaudi-shell-setup %%s\\n" "$*" >> "$MACHINE/calls.log"\n[ -z "${FAKE_HELPER_SETUP_FAIL:-}" ]\n' > "$repo/setup.sh"
    chmod +x "$repo/setup.sh"
    init_git_repo "$repo"
    export GAUDI_HELPER_REPO_URL="$repo"
}

@test "shell helpers: the detected shell is shown" {
    export SHELL="/bin/bash"
    run helpers_step
    assert_success
    assert_output_contains "Detected shell: bash"
}

@test "shell helpers: nothing is installed by default" {
    helper_repository
    run helpers_step
    assert_success
    assert_output_contains "Do you want to install shell helpers? [y/N]"
    refute_called "curl"
    refute_file_exists "$HOME/.gaudi-shell"
}

@test "shell helpers: --yes installs gaudi-shell and oh-my-zsh" {
    helper_repository
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_success
    assert_file_exists "$HOME/.gaudi-shell/setup.sh"
    assert_called "curl -fsSL $OH_MY_ZSH_URL"
    assert_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: gaudi-shell is cloned and set up silently for the detected shell" {
    helper_repository
    export GAUDI_ASSUME_YES="true" SHELL="/bin/zsh"
    run helpers_step
    assert_called "gaudi-shell-setup --silent --shell zsh"

    gaudi_sandbox darwin
    mv "$HOME/.gaudi-shell" "$SANDBOX/first-install"
    mv "$SANDBOX/remotes/gaudi-shell" "$SANDBOX/first-remote"
    helper_repository
    export GAUDI_ASSUME_YES="true" SHELL="/bin/bash"
    run helpers_step
    assert_called "gaudi-shell-setup --silent --shell bash"
}

@test "shell helpers: gaudi-shell is not offered for shells it does not support" {
    helper_repository
    export GAUDI_ASSUME_YES="true" SHELL="/usr/bin/fish"
    run helpers_step
    assert_success
    assert_output_contains "gaudi-shell supports Bash and Zsh: not offered for fish"
    refute_file_exists "$HOME/.gaudi-shell"
    assert_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: an existing gaudi-shell is not reinstalled" {
    helper_repository
    mkdir -p "$HOME/.gaudi-shell"
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_success
    assert_output_contains "gaudi-shell is already installed"
    refute_called "gaudi-shell-setup"
}

@test "shell helpers: a gaudi-shell that cannot be cloned is recorded" {
    export GAUDI_HELPER_REPO_URL="$SANDBOX/remotes/missing" GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_failure 1
    assert_output_contains "gaudi-shell installation (clone)"
    assert_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: a failing gaudi-shell setup is recorded" {
    helper_repository
    export GAUDI_ASSUME_YES="true" FAKE_HELPER_SETUP_FAIL=1
    run helpers_step
    assert_failure 1
    assert_output_contains "gaudi-shell installation (setup)"
}

@test "shell helpers: oh-my-zsh is installed unattended without switching shell or replacing .zshrc" {
    helper_repository
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_called "oh-my-zsh-installer --unattended RUNZSH=no CHSH=no KEEP_ZSHRC=yes"
}

@test "shell helpers: an existing oh-my-zsh is not reinstalled" {
    helper_repository
    mkdir -p "$HOME/.oh-my-zsh"
    export GAUDI_ASSUME_YES="true"
    run helpers_step
    assert_success
    assert_output_contains "oh-my-zsh is already installed"
    refute_called "curl -fsSL $OH_MY_ZSH_URL"
    assert_file_exists "$HOME/.gaudi-shell/setup.sh"
}

@test "shell helpers: zsh users are offered oh-my-zsh first" {
    export SHELL="/bin/zsh"
    interactive
    run helpers_step <<< "ynn"
    assert_success
    [[ "$output" == *"Install oh-my-zsh?"*"Install gaudi-shell?"* ]]
    refute_called "curl"
}

@test "shell helpers: bash users are offered gaudi-shell first" {
    export SHELL="/bin/bash"
    interactive
    run helpers_step <<< "ynn"
    assert_success
    [[ "$output" == *"Install gaudi-shell?"*"Install oh-my-zsh?"* ]]
}

@test "shell helpers: each helper can be chosen on its own" {
    helper_repository
    export SHELL="/bin/zsh"
    interactive
    # helpers: y, oh-my-zsh: n, gaudi-shell: y
    run helpers_step <<< "yny"
    assert_success
    assert_file_exists "$HOME/.gaudi-shell/setup.sh"
    refute_file_exists "$HOME/.oh-my-zsh"
}

@test "shell helpers: a failed oh-my-zsh download is recorded and does not stop gaudi-shell" {
    helper_repository
    export GAUDI_ASSUME_YES="true" FAKE_CURL_FAIL=1
    run helpers_step
    assert_failure 1
    assert_output_contains "oh-my-zsh installation"
    assert_output_contains "1 step(s) failed"
    assert_file_exists "$HOME/.gaudi-shell/setup.sh"
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

@test "Fedora cleanup removes unused packages and clears the dnf cache" {
    gaudi_sandbox fedora
    run step lib/fedora/cleanup.sh
    assert_success
    assert_called "sudo dnf autoremove -y"
    assert_called "sudo dnf clean all"
}

@test "Fedora cleanup records failures and still runs both commands" {
    gaudi_sandbox fedora
    export FAKE_DNF_CLEAN_FAIL=1
    run step lib/fedora/cleanup.sh
    assert_failure 1
    assert_output_contains "2 step(s) failed"
}
