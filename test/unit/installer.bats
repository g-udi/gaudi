#!/usr/bin/env bats
# bin/installer.sh

load ../helper

setup() {
    gaudi_sandbox debian
    add_tool brew
}

# --- gaudi::run_install_command -----------------------------------------------------

@test "run_install_command splits the command and appends the package" {
    run call gaudi::run_install_command "sudo apt-get install -y" curl
    assert_success
    assert_called "sudo apt-get install -y curl"
    assert_file_contains "$MACHINE/apt.txt" "curl"
}

@test "run_install_command passes a package name with spaces as one argument" {
    run call gaudi::run_install_command "sudo apt-get install -y" "two words"
    assert_success
    assert_file_contains "$MACHINE/apt.txt" "two words"
}

@test "run_install_command can run a Gaudi function as the installer" {
    run call gaudi::run_install_command "gaudi::gem_install" tmuxinator
    assert_success
    assert_called "gem install tmuxinator --user-install"
}

@test "run_install_command returns the installer's exit status" {
    export FAKE_APT_FAIL="nope"
    run call gaudi::run_install_command "sudo apt-get install -y" nope
    assert_failure
}

@test "run_install_command fails on an empty command" {
    run call gaudi::run_install_command "" curl
    assert_failure
}

@test "run_install_command only prints the command in a dry run" {
    export GAUDI_DRY_RUN="true"
    run call gaudi::run_install_command "sudo apt-get install -y" curl
    assert_success
    assert_output_equals "DRY RUN: sudo apt-get install -y curl"
    refute_called "apt-get"
}

@test "run_install_command quotes awkward names in a dry run" {
    export GAUDI_DRY_RUN="true"
    run call gaudi::run_install_command "sudo apt-get install -y" "two words"
    assert_output_equals 'DRY RUN: sudo apt-get install -y two\ words'
}

# --- gaudi::install_list_items --------------------------------------------------------------

@test "gaudi::install_list_items installs every item and shows descriptions" {
    run call gaudi::install_list_items "sudo apt-get install -y" "false" "tree::Directory listing" "htop"
    assert_success
    assert_output_contains "Installing tree"
    assert_output_contains "Description: Directory listing"
    assert_output_contains "Installing htop"
    assert_file_contains "$MACHINE/apt.txt" "tree"
    assert_file_contains "$MACHINE/apt.txt" "htop"
}

@test "gaudi::install_list_items prints no description line for an item without one" {
    run call gaudi::install_list_items "sudo apt-get install -y" "false" "htop"
    refute_output_contains "Description:"
}

@test "gaudi::install_list_items keeps everything after the first :: as the description" {
    run call gaudi::install_list_items "sudo apt-get install -y" "false" "coreutils::with_default_names::GNU utilities"
    assert_output_contains "Description: with_default_names::GNU utilities"
    assert_file_contains "$MACHINE/apt.txt" "coreutils"
}

@test "gaudi::install_list_items skips empty items" {
    run call gaudi::install_list_items "sudo apt-get install -y" "false" "" "htop" ""
    assert_success
    assert_equal "$(calls | grep -c "^apt-get install")" "1"
}

@test "gaudi::install_list_items accepts an empty list" {
    run call gaudi::install_list_items "sudo apt-get install -y" "false"
    assert_success
    refute_called "apt-get"
}

@test "gaudi::install_list_items records a failing item and installs the rest" {
    export FAKE_APT_FAIL="broken"
    run call eval 'gaudi::install_list_items "sudo apt-get install -y" "false" "first" "broken" "third"; gaudi::report_failures'
    assert_failure 1
    assert_file_contains "$MACHINE/apt.txt" "first"
    assert_file_contains "$MACHINE/apt.txt" "third"
    refute_file_contains "$MACHINE/apt.txt" "broken"
    assert_output_contains "1 step(s) failed"
    assert_output_contains "broken (sudo apt-get install -y)"
}

@test "gaudi::install_list_items in prompt mode installs only what is confirmed" {
    interactive
    run call gaudi::install_list_items "sudo apt-get install -y" "true" "first" "second" "third" <<< "yny"
    assert_success
    assert_output_contains "Install first? [y/N]"
    assert_file_contains "$MACHINE/apt.txt" "first"
    refute_file_contains "$MACHINE/apt.txt" "second"
    assert_file_contains "$MACHINE/apt.txt" "third"
}

@test "gaudi::install_list_items in prompt mode installs nothing without a terminal" {
    run call gaudi::install_list_items "sudo apt-get install -y" "true" "first" "second"
    assert_success
    refute_called "apt-get"
}

# --- gaudi::bundle_install -------------------------------------------------------------

@test "bundle_install runs brew bundle on the Brewfile" {
    printf 'brew "jq"\ncask "kitty"\n' > "$SANDBOX/Brewfile"
    run call gaudi::bundle_install "$SANDBOX/Brewfile"
    assert_success
    assert_called "brew bundle install --file=$SANDBOX/Brewfile"
    refute_called "--no-upgrade"
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
}

@test "bundle_install adds --no-upgrade when GAUDI_BUNDLE_NO_UPGRADE is true" {
    printf 'brew "jq"\n' > "$SANDBOX/Brewfile"
    export GAUDI_BUNDLE_NO_UPGRADE="true"
    run call gaudi::bundle_install "$SANDBOX/Brewfile"
    assert_success
    assert_called "brew bundle install --file=$SANDBOX/Brewfile --no-upgrade"
}

@test "bundle_install handles a Brewfile path with spaces" {
    mkdir -p "$SANDBOX/my templates"
    printf 'brew "jq"\n' > "$SANDBOX/my templates/Brewfile"
    run call gaudi::bundle_install "$SANDBOX/my templates/Brewfile"
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
}

@test "bundle_install returns brew's failure" {
    printf 'brew "jq"\nbrew "broken"\n' > "$SANDBOX/Brewfile"
    export FAKE_BREW_FAIL="broken"
    run call gaudi::bundle_install "$SANDBOX/Brewfile"
    assert_failure
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
}

@test "bundle_install only prints the command in a dry run" {
    printf 'brew "jq"\n' > "$SANDBOX/Brewfile"
    export GAUDI_DRY_RUN="true"
    run call gaudi::bundle_install "$SANDBOX/Brewfile"
    assert_success
    assert_output_equals "DRY RUN: brew bundle install --file=$SANDBOX/Brewfile"
    refute_called "brew"
}

# --- gaudi::gem_install -------------------------------------------------------------------

@test "gem_install installs a gem that is not there yet" {
    run call gaudi::gem_install tmuxinator
    assert_success
    assert_called "gem install tmuxinator --user-install"
    refute_called "gem update"
}

@test "gem_install updates a gem that is already installed" {
    printf 'tmuxinator\n' > "$MACHINE/gem.txt"
    run call gaudi::gem_install tmuxinator
    assert_success
    assert_called "gem update tmuxinator --user-install"
    refute_called "gem install"
}

@test "gem_install matches the gem name exactly" {
    printf 'rake\n' > "$MACHINE/gem.txt"
    run call gaudi::gem_install rak
    assert_success
    assert_called "gem list --installed --exact rak"
    assert_called "gem install rak --user-install"
}

@test "gem_install_or_update, the older name, still installs (with or without the old first argument)" {
    run call gem_install_or_update install tmuxinator
    assert_success
    assert_called "gem install tmuxinator --user-install"
    run call gem_install_or_update rake
    assert_success
    assert_called "gem install rake --user-install"
}

@test "installSoftwareList, the older name, still installs a list" {
    gaudi_sandbox debian
    run call installSoftwareList "sudo apt-get install -y" false "tree::Directory listing" htop
    assert_success
    assert_called "apt-get install -y tree"
    assert_called "apt-get install -y htop"
}

@test "gem_install returns gem's failure" {
    export FAKE_GEM_FAIL="broken"
    run call gaudi::gem_install broken
    assert_failure
}
