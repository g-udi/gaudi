#!/usr/bin/env bats
# lib/osx/install-pre-requisits.sh and lib/debian/install-pre-requisits.sh

load ../helper

HOMEBREW_INSTALLER="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

osx_step() {
    step lib/osx/install-pre-requisits.sh
}

debian_step() {
    step lib/debian/install-pre-requisits.sh
}

# --- macOS -------------------------------------------------------------------------

@test "macOS: with Homebrew and the Command Line Tools present nothing is installed" {
    gaudi_sandbox darwin
    run osx_step
    assert_success
    refute_called "curl -fsSL"
    refute_called "xcode-select --install"
    refute_called "brew install"
    assert_output_contains "git is installed"
    assert_output_contains "mas is installed"
}

@test "macOS: Homebrew is loaded into the shell profile" {
    gaudi_sandbox darwin
    run osx_step
    assert_success
    assert_file_contains "$HOME/.zshrc" "eval \"\$($FAKEBIN/brew shellenv)\""
}

@test "macOS: a missing Homebrew is installed, loaded and persisted" {
    gaudi_sandbox darwin
    remove_tool brew

    run osx_step
    assert_success
    assert_called "curl -fsSL $HOMEBREW_INSTALLER"
    assert_called "homebrew-installer NONINTERACTIVE="
    refute_called "NONINTERACTIVE=1"
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$HOME/.zshrc" "eval \"\$($FAKE_BREW_PREFIX/bin/brew shellenv)\""
}

@test "macOS: --yes installs Homebrew without prompting" {
    gaudi_sandbox darwin
    remove_tool brew
    export GAUDI_ASSUME_YES="true"

    run osx_step
    assert_success
    assert_called "homebrew-installer NONINTERACTIVE=1"
}

@test "macOS: a failing Homebrew installer is recorded and brew steps are skipped" {
    gaudi_sandbox darwin
    remove_tool brew
    export FAKE_HOMEBREW_INSTALL_FAIL=1

    run osx_step
    assert_failure 1
    assert_output_contains "Homebrew installation"
    assert_output_contains "Homebrew is not available: brew-based steps will be skipped"
    refute_called "brew install"
}

@test "macOS: a failed installer download is recorded, not ignored" {
    gaudi_sandbox darwin
    remove_tool brew
    export FAKE_CURL_FAIL=1

    run osx_step
    assert_failure 1
    assert_output_contains "Could not download $HOMEBREW_INSTALLER"
    assert_output_contains "Homebrew installation"
}

@test "macOS: missing Command Line Tools open the installer and ask for a rerun" {
    gaudi_sandbox darwin
    rm "$MACHINE/clt"

    run osx_step
    assert_success
    assert_called "xcode-select --install"
    assert_output_contains "Xcode Command Line Tools are not installed"
}

@test "macOS: git and mas are installed with brew when missing" {
    gaudi_sandbox darwin
    remove_tool mas git

    run osx_step
    assert_success
    assert_called "brew install git"
    assert_called "brew install mas"
}

@test "macOS: a prerequisite that fails to install is recorded and the next one is tried" {
    gaudi_sandbox darwin
    remove_tool mas git
    export FAKE_BREW_FAIL="git"

    run osx_step
    assert_failure 1
    assert_output_contains "git (brew install)"
    assert_called "brew install mas"
}

# --- Debian / Ubuntu -------------------------------------------------------------------

@test "Debian: apt is updated and the build prerequisites are installed with sudo" {
    gaudi_sandbox debian
    run debian_step
    assert_success
    assert_called "sudo apt-get update"
    assert_called "sudo apt-get install -y build-essential ca-certificates curl file git libssl-dev procps"
    for package in build-essential ca-certificates curl file git libssl-dev procps; do
        assert_file_contains "$MACHINE/apt.txt" "$package"
    done
}

@test "Debian: a failing apt-get update is recorded and the install is still attempted" {
    gaudi_sandbox debian
    export FAKE_APT_UPDATE_FAIL=1

    run debian_step
    assert_failure 1
    assert_output_contains "apt-get update"
    assert_called "apt-get install -y build-essential"
}

@test "Debian: a failing prerequisite install is recorded" {
    gaudi_sandbox debian
    export FAKE_APT_FAIL="libssl-dev"

    run debian_step
    assert_failure 1
    assert_output_contains "Debian prerequisites (apt-get install)"
}

@test "Debian: Homebrew is not installed unless asked for" {
    gaudi_sandbox debian
    run debian_step
    assert_success
    assert_output_contains "Install Homebrew on Linux? It is required for Brewfiles. [y/N]"
    refute_called "curl -fsSL"
    refute_file_exists "$FAKE_BREW_PREFIX/bin/brew"
}

@test "Debian: accepting installs Homebrew and persists it in the profile" {
    gaudi_sandbox debian
    export GAUDI_ASSUME_YES="true" SHELL="/bin/bash"

    run debian_step
    assert_success
    assert_called "curl -fsSL $HOMEBREW_INSTALLER"
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$HOME/.bashrc" "eval \"\$($FAKE_BREW_PREFIX/bin/brew shellenv)\""
}

@test "Debian: an existing Homebrew is not reinstalled, just loaded" {
    gaudi_sandbox debian
    add_tool brew

    run debian_step
    assert_success
    refute_output_contains "Install Homebrew on Linux?"
    refute_called "curl -fsSL"
    assert_file_contains "$HOME/.zshrc" "brew shellenv"
}

@test "Debian: a failing Homebrew installer is recorded" {
    gaudi_sandbox debian
    export GAUDI_ASSUME_YES="true" FAKE_HOMEBREW_INSTALL_FAIL=1

    run debian_step
    assert_failure 1
    assert_output_contains "Homebrew installation"
}

@test "Debian as root: Homebrew is not attempted, because it refuses to run as root" {
    gaudi_sandbox debian
    export GAUDI_ASSUME_YES="true" FAKE_UID=0

    run debian_step
    assert_success
    assert_output_contains "Homebrew cannot be installed as root"
    refute_called "curl -fsSL"
    refute_file_exists "$FAKE_BREW_PREFIX/bin/brew"
}

@test "Debian as root without sudo: apt runs directly" {
    gaudi_sandbox debian
    remove_tool sudo
    export FAKE_UID=0

    run debian_step
    assert_success
    refute_called "sudo"
    assert_file_contains "$MACHINE/apt.txt" "build-essential"
}

@test "Debian without sudo and without root: the missing privilege is reported" {
    gaudi_sandbox debian
    remove_tool sudo

    run debian_step
    assert_failure 1
    assert_output_contains "This step needs root: install sudo or run Gaudi as root"
    assert_output_contains "apt-get update"
    refute_called "apt-get"
}

# --- Fedora ------------------------------------------------------------------------------

fedora_step() {
    step lib/fedora/install-pre-requisits.sh
}

@test "Fedora: the build prerequisites are installed with dnf" {
    gaudi_sandbox fedora
    run fedora_step
    assert_success
    assert_called "sudo dnf install -y gcc gcc-c++ make procps-ng file git"
    assert_file_contains "$MACHINE/dnf.txt" "gcc"
}

@test "Fedora: curl is only installed when it is missing (the image's curl-minimal conflicts with it)" {
    gaudi_sandbox fedora
    run fedora_step
    refute_called "git curl"

    gaudi_sandbox fedora
    remove_tool curl
    run fedora_step
    assert_called "sudo dnf install -y gcc gcc-c++ make procps-ng file git curl"
}

@test "Fedora: a failing prerequisite install is recorded" {
    gaudi_sandbox fedora
    export FAKE_DNF_FAIL="make"
    run fedora_step
    assert_failure 1
    assert_output_contains "Fedora prerequisites (dnf install)"
}

@test "Fedora: Homebrew is offered to a regular user and skipped for root" {
    gaudi_sandbox fedora
    export GAUDI_ASSUME_YES="true"
    run fedora_step
    assert_success
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"

    gaudi_sandbox fedora
    export GAUDI_ASSUME_YES="true" FAKE_UID=0
    run fedora_step
    assert_success
    assert_output_contains "Homebrew cannot be installed as root"
    refute_called "curl -fsSL"
}

# --- Arch and openSUSE ---------------------------------------------------------------------

@test "Arch: the package database is refreshed and the build prerequisites installed with pacman" {
    gaudi_sandbox arch
    run step lib/arch/install-pre-requisits.sh
    assert_success
    assert_called "sudo pacman -Sy --noconfirm --needed base-devel procps-ng curl file git"
    assert_file_contains "$MACHINE/pacman.txt" "base-devel"
}

@test "Arch: a failing prerequisite install is recorded" {
    gaudi_sandbox arch
    export FAKE_PACMAN_FAIL="base-devel"
    run step lib/arch/install-pre-requisits.sh
    assert_failure 1
    assert_output_contains "Arch prerequisites (pacman)"
}

@test "openSUSE: the build prerequisites are installed with zypper, without prompting" {
    gaudi_sandbox opensuse
    run step lib/opensuse/install-pre-requisits.sh
    assert_success
    assert_called "sudo zypper --non-interactive install gcc gcc-c++ make procps curl file git findutils diffutils"
    assert_file_contains "$MACHINE/zypper.txt" "gcc-c++"
}

@test "openSUSE: a failing prerequisite install is recorded" {
    gaudi_sandbox opensuse
    export FAKE_ZYPPER_FAIL="make"
    run step lib/opensuse/install-pre-requisits.sh
    assert_failure 1
    assert_output_contains "openSUSE prerequisites (zypper install)"
}

@test "offer_linuxbrew: declined by default, installed with --yes, skipped for root, left alone when present" {
    gaudi_sandbox arch
    run call gaudi::offer_linuxbrew
    assert_success
    assert_output_contains "Install Homebrew on Linux? It is required for Brewfiles. [y/N]"
    refute_called "curl -fsSL"

    export GAUDI_ASSUME_YES="true"
    run call eval 'get_os; get_shell_type; gaudi::offer_linuxbrew'
    assert_success
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$HOME/.zshrc" "brew shellenv"

    gaudi_sandbox opensuse
    export GAUDI_ASSUME_YES="true" FAKE_UID=0
    run call gaudi::offer_linuxbrew
    assert_output_contains "Homebrew cannot be installed as root"
    refute_called "curl -fsSL"

    gaudi_sandbox opensuse
    add_tool brew
    run call eval 'get_os; get_shell_type; gaudi::offer_linuxbrew'
    assert_success
    refute_output_contains "Install Homebrew on Linux?"
}
