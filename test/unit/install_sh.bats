#!/usr/bin/env bats
# install.sh: the one-line installer (prerequisites, clone or update, hand over to setup.sh)

bats_require_minimum_version 1.5.0
load ../helper

SKIP_ALL="--yes --skip-prereqs --skip-ssh --skip-templates --skip-software --skip-configs --skip-shell-helpers --skip-dotfiles --skip-cleanup"

setup() {
    gaudi_sandbox darwin
    REMOTE="$(gaudi_remote)"
    export GAUDI_REPO_URL="file://$REMOTE"
}

install() {
    # shellcheck disable=SC2086
    bash "$GAUDI_ROOT/install.sh" "$@"
}

# Add a commit to the Gaudi repository the installer clones from
publish() {
    printf '%s\n' "$2" > "$REMOTE/$1"
    git -C "$REMOTE" add -A
    git -C "$REMOTE" commit -q -m "update"
}

# --- clone and hand over -------------------------------------------------------------

@test "a fresh install clones Gaudi into ~/.gaudi and runs setup" {
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_file_exists "$HOME/.gaudi/.git"
    assert_file_exists "$HOME/.gaudi/setup.sh"
    assert_output_contains "[INFO] Install root: $HOME/.gaudi"
    assert_output_contains "[OK] Gaudi setup finished"
    [[ -L "$HOME/.local/bin/gaudi" ]]
}

@test "the installed CLI works afterwards" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    run "$HOME/.local/bin/gaudi" doctor
    assert_success
    assert_output_contains "[INFO] Gaudi: $HOME/.gaudi"
}

@test "arguments are passed on to setup.sh" {
    run install --no-such-flag
    assert_failure 64
    assert_output_contains "Unknown option: --no-such-flag"
}

@test "GAUDI chooses the install directory" {
    export GAUDI="$SANDBOX/custom-gaudi"
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_file_exists "$SANDBOX/custom-gaudi/setup.sh"
    refute_file_exists "$HOME/.gaudi"
}

@test "the clone is shallow" {
    publish "second.txt" "second commit"
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_equal "$(git -C "$HOME/.gaudi" rev-list --count HEAD)" "1"
    assert_file_exists "$HOME/.gaudi/second.txt"
}

@test "GAUDI_BRANCH installs another branch" {
    git -C "$REMOTE" checkout -q -b next
    publish "only-on-next.txt" "next"
    git -C "$REMOTE" checkout -q main
    export GAUDI_BRANCH="next"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_file_exists "$HOME/.gaudi/only-on-next.txt"
}

@test "an existing checkout is updated instead of cloned again" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    publish "added-later.txt" "later"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_output_contains "Updating existing Gaudi checkout at $HOME/.gaudi"
    assert_file_exists "$HOME/.gaudi/added-later.txt"
}

@test "updating works again and again as upstream moves on" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    for round in one two three; do
        publish "round-$round.txt" "$round"
        # shellcheck disable=SC2086
        run install $SKIP_ALL
        assert_success
        assert_file_exists "$HOME/.gaudi/round-$round.txt"
    done
}

@test "an update keeps the templates directory inside the checkout" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    printf 'brew "mine"\n' | write_file "$HOME/.gaudi/templates/Brewfile"
    publish "added-later.txt" "later"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_file_exists "$HOME/.gaudi/added-later.txt"
    assert_file_contains "$HOME/.gaudi/templates/Brewfile" 'brew "mine"'
}

@test "local changes to the checkout are never discarded by an update" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    printf '# my local tweak\n' >> "$HOME/.gaudi/backup.sh"
    publish "added-later.txt" "later"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_output_contains "Local changes found in $HOME/.gaudi: keeping the installed version."
    assert_file_contains "$HOME/.gaudi/backup.sh" "# my local tweak"
    refute_file_exists "$HOME/.gaudi/added-later.txt"
}

@test "a non-Git directory in the way is never overwritten" {
    mkdir -p "$HOME/.gaudi"
    printf 'precious\n' > "$HOME/.gaudi/notes.txt"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "Refusing to overwrite non-Git path: $HOME/.gaudi"
    assert_file_contains "$HOME/.gaudi/notes.txt" "precious"
    refute_file_exists "$HOME/.gaudi/setup.sh"
}

@test "an unreachable repository fails without leaving a half install" {
    export GAUDI_REPO_URL="file://$SANDBOX/remotes/missing"
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure
    refute_file_exists "$HOME/.gaudi/setup.sh"
}

# --- macOS prerequisites ---------------------------------------------------------------

@test "macOS with the Command Line Tools installs nothing first" {
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    refute_called "curl"
    refute_called "xcode-select --install"
    refute_called "brew install"
}

@test "a fresh Mac gets Homebrew (and with it the Command Line Tools) before cloning" {
    remove_tool brew
    rm "$MACHINE/clt"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_called "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_called "homebrew-installer"
    assert_file_exists "$MACHINE/clt"
    assert_file_exists "$HOME/.gaudi/setup.sh"
}

@test "a failed Homebrew download stops the install with a clear message" {
    remove_tool brew
    rm "$MACHINE/clt"
    export FAKE_CURL_FAIL=1

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "Could not download the Homebrew installer"
    refute_file_exists "$HOME/.gaudi"
}

@test "missing Command Line Tools with Homebrew present: open the installer and ask for a rerun" {
    rm "$MACHINE/clt"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_called "xcode-select --install"
    assert_output_contains "Xcode Command Line Tools are missing"
    refute_called "curl"
    refute_file_exists "$HOME/.gaudi"
}

@test "Homebrew outside PATH is still found when the Command Line Tools are missing" {
    remove_tool brew
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    cp "$FAKES_DIR/brew" "$FAKE_BREW_PREFIX/bin/brew"
    rm "$MACHINE/clt"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "Xcode Command Line Tools are missing"
    refute_called "curl"
}

@test "macOS without git installs it with Homebrew" {
    remove_tool git

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "brew install git"
}

# --- Linux and other systems ---------------------------------------------------------------

@test "Linux with git and curl installs nothing first" {
    gaudi_sandbox debian
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export GAUDI_REPO_URL

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    refute_called "apt-get"
    assert_file_exists "$HOME/.gaudi/setup.sh"
}

@test "Debian without git installs git, curl and certificates with apt" {
    gaudi_sandbox debian
    remove_tool git

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "sudo apt-get update"
    assert_called "sudo apt-get install -y ca-certificates curl git"
}

@test "Debian without curl installs it too" {
    gaudi_sandbox debian
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export GAUDI_REPO_URL
    remove_tool curl

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_called "sudo apt-get install -y ca-certificates curl git"
}

@test "a Linux without apt and without git explains what is needed" {
    gaudi_sandbox debian
    remove_tool git apt-get apt-mark

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "git and curl are required"
}

@test "another OS without git explains what is needed" {
    export FAKE_UNAME="FreeBSD"
    remove_tool git

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "git is required"
}

@test "another OS with git still clones, then setup reports it as unsupported" {
    export FAKE_UNAME="FreeBSD"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_file_exists "$HOME/.gaudi/setup.sh"
    assert_output_contains "Gaudi currently automates macOS, Debian/Ubuntu, Fedora, Arch and openSUSE"
}

# --- the documented one-liner ----------------------------------------------------------

@test "flags given to the curl one-liner reach setup.sh" {
    # README: bash -c "$(curl -fsSL .../install.sh)" gaudi --yes --skip-ssh
    # shellcheck disable=SC2086
    run bash -c "$(cat "$GAUDI_ROOT/install.sh")" gaudi $SKIP_ALL
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    assert_file_exists "$HOME/.gaudi/setup.sh"
}

@test "an unknown flag given to the curl one-liner is rejected by setup.sh" {
    run bash -c "$(cat "$GAUDI_ROOT/install.sh")" gaudi --no-such-flag
    assert_failure 64
    assert_output_contains "Unknown option: --no-such-flag"
}

# --- root without sudo (containers, minimal servers) -----------------------------------

@test "Debian as root without sudo: the installer runs apt directly" {
    gaudi_sandbox debian
    remove_tool git sudo
    export FAKE_UID=0

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "apt-get install -y ca-certificates curl git"
    refute_called "sudo"
}

@test "Debian without sudo and without root: the installer says what is needed" {
    gaudi_sandbox debian
    remove_tool git sudo

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_failure 1
    assert_output_contains "This step needs root: install sudo or run this installer as root."
    refute_called "apt-get"
}

# --- Fedora ------------------------------------------------------------------------------

@test "Fedora without git installs it with dnf, leaving the image's curl alone" {
    gaudi_sandbox fedora
    remove_tool git

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "sudo dnf install -y git"
    refute_called "curl git"
}

@test "Fedora without curl installs curl and git" {
    gaudi_sandbox fedora
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export GAUDI_REPO_URL
    remove_tool curl

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_called "sudo dnf install -y curl git"
}

# --- Arch and openSUSE ---------------------------------------------------------------------

@test "Arch without git installs curl and git with pacman" {
    gaudi_sandbox arch
    remove_tool git

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "sudo pacman -Sy --noconfirm --needed curl git"
}

@test "openSUSE without git installs curl and git with zypper" {
    gaudi_sandbox opensuse
    remove_tool git

    # shellcheck disable=SC2086
    run -127 install $SKIP_ALL
    assert_called "sudo zypper --non-interactive install curl git"
}

@test "files that other tools keep next to Gaudi do not block an update" {
    # shellcheck disable=SC2086
    install $SKIP_ALL >/dev/null 2>&1
    mkdir -p "$HOME/.gaudi/widgets" "$HOME/.gaudi/gaudi-helper"
    printf 'data\n' > "$HOME/.gaudi/widgets/state.json"
    publish "added-later.txt" "later"

    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    refute_output_contains "Local changes found"
    assert_file_exists "$HOME/.gaudi/added-later.txt"
    assert_file_contains "$HOME/.gaudi/widgets/state.json" "data"
}

@test "--yes installs Homebrew without waiting for RETURN; without it Homebrew may ask" {
    remove_tool brew
    rm "$MACHINE/clt"
    # shellcheck disable=SC2086
    run install $SKIP_ALL
    assert_success
    assert_called "homebrew-installer NONINTERACTIVE=1"

    gaudi_sandbox darwin
    REMOTE="$(gaudi_remote)"
    export GAUDI_REPO_URL="file://$REMOTE"
    remove_tool brew
    rm "$MACHINE/clt"
    # shellcheck disable=SC2086
    run install ${SKIP_ALL#--yes }
    assert_success
    assert_called "homebrew-installer NONINTERACTIVE="
    refute_called "NONINTERACTIVE=1"

    gaudi_sandbox darwin
    REMOTE="$(gaudi_remote)"
    export GAUDI_REPO_URL="file://$REMOTE" GAUDI_ASSUME_YES="true"
    remove_tool brew
    rm "$MACHINE/clt"
    # shellcheck disable=SC2086
    run install ${SKIP_ALL#--yes }
    assert_success
    assert_called "homebrew-installer NONINTERACTIVE=1"
}
