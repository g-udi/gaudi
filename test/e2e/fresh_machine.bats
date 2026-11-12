#!/usr/bin/env bats
# End to end: a brand-new machine, the one-line installer, nothing else.
#
# The real install.sh, setup.sh and every real stage run here. Only the
# machine is simulated: package managers, curl, sudo and friends are the fakes
# in test/fakes, and Gaudi and its templates are cloned from local Git
# repositories instead of GitHub.

load ../helper

# Publish the checkout under test and a templates repository, like GitHub would
publish_repositories() {
    TEMPLATES_REMOTE="$SANDBOX/remotes/templates"
    standard_templates "$TEMPLATES_REMOTE"
    init_git_repo "$TEMPLATES_REMOTE"
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export GAUDI_REPO_URL
    export GAUDI_DEFAULT_TEMPLATES_URL="$TEMPLATES_REMOTE"

    # gaudi-shell, with its component submodules
    gshell_remote
}

fresh_mac() {
    gaudi_sandbox darwin
    remove_tool brew
    rm "$MACHINE/clt"
    publish_repositories
}

fresh_debian() {
    gaudi_sandbox debian
    publish_repositories
}

install() {
    bash "$GAUDI_ROOT/install.sh" "$@" </dev/null
}

EXPECTED_MAC_SOFTWARE='[brew/brew.txt]
example/tap/special
jq
[brew/cargo.txt]
ripgrep
[brew/cask.txt]
kitty
raycast
[brew/go.txt]
golang.org/x/tools/gopls
[brew/mas.txt]
Amphetamine|937984704
[brew/npm.txt]
eslint
[brew/tap.txt]
example/tap
[brew/uv.txt]
pylint
[brew/vscode.txt]
esbenp.prettier-vscode
[gem.txt]
tmuxinator'

@test "fresh Mac: one command installs Homebrew, Gaudi, the templates, all software and configs" {
    fresh_mac

    run install --yes
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"

    # Homebrew came from its installer and is available in new shells
    assert_called "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$HOME/.zshrc" "eval \"\$($FAKE_BREW_PREFIX/bin/brew shellenv)\""

    # Gaudi and the templates were cloned
    assert_file_exists "$HOME/.gaudi/.git"
    assert_file_exists "$HOME/.gaudi/templates/.git"
    assert_file_exists "$HOME/.gaudi/templates/lists/core.Brewfile"

    # Every Brewfile and list was installed
    assert_equal "$(machine_snapshot)" "$EXPECTED_MAC_SOFTWARE"

    # Hooks ran around the right steps, in order
    assert_equal "$(cat "$MACHINE/hooks.log")" "pre.bundle
pre.bundle-core
post.bundle-core
post.bundle-core.extra
post.bundle
post.gem"

    # macOS and shared configs were applied; the Debian one was not
    assert_file_contains "$MACHINE/defaults.txt" "write com.apple.finder ShowPathbar -bool true"
    assert_equal "$(cat "$MACHINE/configs.log")" "shared-config"

    # Shell helpers and cleanup ran
    assert_file_exists "$HOME/.oh-my-zsh"
    assert_file_exists "$HOME/.gaudi-shell/setup.sh"
    assert_called "gaudi-shell-setup --silent --shell zsh"
    assert_called "brew cleanup -s"

    # No terminal: the SSH key step was skipped rather than left hanging
    refute_called "ssh-keygen"

    # The CLI is installed and on the PATH of new shells
    assert_equal "$(readlink "$HOME/.local/bin/gaudi")" "$HOME/.gaudi/bin/gaudi"
    assert_file_contains "$HOME/.zshrc" "export PATH=\"$HOME/.local/bin:\$PATH\""
    assert_cwd_clean
}

@test "fresh Mac: the installed CLI works straight away" {
    fresh_mac
    install --yes >/dev/null 2>&1

    run "$HOME/.local/bin/gaudi" doctor
    assert_success
    assert_output_contains "[INFO] Gaudi: $HOME/.gaudi"
    assert_output_contains "[INFO] Brewfiles found: 3"
    assert_output_contains "[OK] Homebrew is available"
}

@test "fresh Mac: running the installer again changes nothing" {
    fresh_mac
    install --yes >/dev/null 2>&1
    before="$(machine_snapshot)"
    profile_before="$(cat "$HOME/.zshrc")"

    run install --yes
    assert_success
    assert_output_contains "Updating existing Gaudi checkout at $HOME/.gaudi"
    assert_output_contains "Update existing templates at $HOME/.gaudi/templates?"
    assert_equal "$(machine_snapshot)" "$before"
    assert_equal "$(cat "$HOME/.zshrc")" "$profile_before"
    # Homebrew is not downloaded a second time
    assert_equal "$(calls | grep -c '^homebrew-installer')" "1"
}

@test "fresh Mac: new templates are picked up by the next run" {
    fresh_mac
    install --yes >/dev/null 2>&1
    printf 'brew "added-later"\n' > "$TEMPLATES_REMOTE/lists/later.Brewfile"
    git -C "$TEMPLATES_REMOTE" add -A
    git -C "$TEMPLATES_REMOTE" commit -q -m "more software"

    run install --yes
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "added-later"
}

@test "fresh Mac: without --yes and without a terminal, only the safe defaults happen" {
    fresh_mac

    run install
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    # Templates are cloned (default yes), but nothing optional is installed
    assert_file_exists "$HOME/.gaudi/templates/lists/core.Brewfile"
    assert_equal "$(machine_snapshot)" ""
    # Only the hooks that wrap whole stages ran; none for a declined Brewfile
    assert_equal "$(cat "$MACHINE/hooks.log")" "pre.bundle
post.bundle
post.gem"
    refute_file_exists "$MACHINE/defaults.txt"
    refute_file_exists "$HOME/.oh-my-zsh"
    refute_called "brew cleanup"
}

@test "fresh Debian: one command installs prerequisites, Homebrew, apt and Brewfile software" {
    fresh_debian

    run install --yes
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"

    # apt prerequisites and the apt list
    for package in build-essential ca-certificates curl file git libssl-dev procps tree htop; do
        assert_file_contains "$MACHINE/apt.txt" "$package"
    done

    # Homebrew on Linux, then the same Brewfiles as on macOS
    assert_file_exists "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"

    # Debian and shared configs, never the macOS one
    assert_equal "$(sort "$MACHINE/configs.log")" "debian-config
shared-config"
    refute_file_exists "$MACHINE/defaults.txt"

    # apt hooks ran, apt cleanup ran
    assert_file_contains "$MACHINE/hooks.log" "pre.apt"
    assert_called "sudo apt-get autoremove -y"
    assert_called "sudo apt-get clean"
    assert_cwd_clean
}

@test "fresh Debian: when Homebrew cannot be installed, apt software still is" {
    fresh_debian
    export FAKE_HOMEBREW_INSTALL_FAIL=1

    run install --yes
    assert_failure 1
    assert_output_contains "Homebrew installation"
    assert_output_contains "Skipping 3 Brewfile(s): Homebrew is not available"
    assert_output_contains "Gaudi setup finished with failures"
    assert_file_contains "$MACHINE/apt.txt" "tree"
    assert_file_contains "$MACHINE/apt.txt" "htop"
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"
    refute_file_exists "$MACHINE/brew/brew.txt"
}

@test "a dry run of the whole setup changes nothing on the machine" {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_DRY_RUN="true"
    standard_templates "$GAUDI_TEMPLATES_LOCATION"

    run "$GAUDI_ROOT/setup.sh" --yes --skip-prereqs --skip-ssh --skip-templates --skip-shell-helpers --skip-cleanup </dev/null
    assert_success
    assert_output_contains "DRY RUN: brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
    assert_output_contains "DRY RUN: hook $GAUDI_TEMPLATES_LOCATION/hooks/pre.bundle.hooks.sh"
    assert_output_contains "DRY RUN: gaudi::gem_install tmuxinator"
    assert_output_contains "DRY RUN: config $GAUDI_TEMPLATES_LOCATION/configs/finder_pathbar.configs.osx.sh"
    assert_equal "$(machine_snapshot)" ""
    refute_file_exists "$MACHINE/hooks.log"
    refute_file_exists "$MACHINE/configs.log"
    refute_file_exists "$MACHINE/defaults.txt"
    refute_called "brew bundle"
}

@test "the README's safe smoke command installs only the CLI" {
    gaudi_sandbox darwin

    run "$GAUDI_ROOT/setup.sh" --yes --skip-prereqs --skip-templates --skip-software --skip-configs --skip-shell-helpers --skip-ssh --skip-dotfiles --skip-cleanup
    assert_success
    assert_equal "$(machine_snapshot)" ""
    assert_equal "$(calls | grep -v '^uname' || true)" ""
    [[ -L "$HOME/.local/bin/gaudi" ]]
}

@test "fresh Fedora: one command installs prerequisites, Homebrew, dnf and Brewfile software" {
    gaudi_sandbox fedora
    publish_repositories
    printf '# @List: dnfList\ndnfList=( "tree" "htop" )\n' > "$TEMPLATES_REMOTE/lists/default.dnf.list.sh"
    printf '_info="Fedora only config"\n_command() { printf "fedora-config\\n" >> "$MACHINE/configs.log"; }\n' > "$TEMPLATES_REMOTE/configs/selinux.configs.fedora.sh"
    git -C "$TEMPLATES_REMOTE" add -A
    git -C "$TEMPLATES_REMOTE" commit -q -m "fedora"

    run install --yes
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    for package in gcc make git tree htop; do
        assert_file_contains "$MACHINE/dnf.txt" "$package"
    done
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_equal "$(sort "$MACHINE/configs.log")" "fedora-config
shared-config"
    assert_called "sudo dnf autoremove -y"
    refute_called "apt-get"
}

@test "a root user on a server without sudo gets apt software, and Brewfiles are skipped with a reason" {
    fresh_debian
    remove_tool sudo
    export FAKE_UID=0

    run install --yes
    assert_success
    assert_output_contains "Homebrew cannot be installed as root"
    assert_output_contains "Skipping 3 Brewfile(s): Homebrew is not available"
    assert_file_contains "$MACHINE/apt.txt" "tree"
    refute_called "sudo"
}

@test "fresh Arch and fresh openSUSE: one command installs prerequisites, Homebrew, native lists and Brewfiles" {
    for os in arch opensuse; do
        gaudi_sandbox "$os"
        use_machine "fresh-$os"
        TEMPLATES_REMOTE="$SANDBOX/remotes/templates-$os"
        standard_templates "$TEMPLATES_REMOTE"
        manager="pacman"
        [[ "$os" == "opensuse" ]] && manager="zypper"
        printf '# @List: %sList\n%sList=( "tree" "htop" )\n' "$manager" "$manager" > "$TEMPLATES_REMOTE/lists/default.$manager.list.sh"
        init_git_repo "$TEMPLATES_REMOTE"
        GAUDI_REPO_URL="file://$(gaudi_remote)"
        export GAUDI_REPO_URL GAUDI_DEFAULT_TEMPLATES_URL="$TEMPLATES_REMOTE"

        run install --yes --skip-shell-helpers
        assert_success
        assert_output_contains "[OK] Gaudi setup finished"
        assert_file_contains "$MACHINE/$manager.txt" "tree"
        assert_file_contains "$MACHINE/$manager.txt" "git"
        assert_file_contains "$MACHINE/brew/brew.txt" "jq"
        assert_equal "$(cat "$MACHINE/configs.log")" "shared-config"
    done
}
