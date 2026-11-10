#!/usr/bin/env bats
# End to end: things going wrong, and awkward environments.

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    standard_templates "$GAUDI_TEMPLATES_LOCATION"
}

full_setup() {
    "$GAUDI_ROOT/setup.sh" --yes --skip-ssh --skip-shell-helpers --skip-templates "$@" </dev/null
}

@test "a failing package, a failing hook and a failing config are all reported, and everything else is done" {
    export FAKE_BREW_FAIL="raycast"
    printf 'false\n' > "$GAUDI_TEMPLATES_LOCATION/hooks/post.bundle.hooks.sh"
    printf '_info="Broken config"\n_command() { return 1; }\n' > "$GAUDI_TEMPLATES_LOCATION/configs/broken.configs.osx.sh"

    run full_setup
    assert_failure 1
    assert_output_contains "3 step(s) failed:"
    assert_output_contains "some entries in $GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"
    assert_output_contains "hook $GAUDI_TEMPLATES_LOCATION/hooks/post.bundle.hooks.sh"
    assert_output_contains "config Broken config"
    assert_output_contains "Gaudi setup finished with failures"

    # The rest of the run still happened
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/npm.txt" "eslint"
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"
    assert_file_contains "$MACHINE/defaults.txt" "ShowPathbar"
    assert_called "brew cleanup -s"
}

@test "after fixing what failed, running the same command again finishes the job" {
    export FAKE_BREW_FAIL="raycast"
    run full_setup
    assert_failure 1

    unset FAKE_BREW_FAIL
    run full_setup
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    assert_file_contains "$MACHINE/brew/cask.txt" "raycast"
}

@test "an unreachable templates repository fails the run but the other stages still happen" {
    unset GAUDI_TEMPLATES_LOCATION
    export GAUDI="$SANDBOX/gaudi-home" GAUDI_DEFAULT_TEMPLATES_URL="$SANDBOX/remotes/missing"
    mkdir -p "$GAUDI"
    cp -R "$GAUDI_ROOT/bin" "$GAUDI_ROOT/lib" "$GAUDI_ROOT/configs" "$GAUDI_ROOT/setup.sh" "$GAUDI/"

    run "$GAUDI/setup.sh" --yes --skip-ssh --skip-shell-helpers </dev/null
    assert_failure 1
    assert_output_contains "templates: no reachable repository"
    assert_output_contains "Template directory not found"
    [[ -L "$HOME/.local/bin/gaudi" ]]
    assert_called "brew cleanup -s"
}

@test "no network on a fresh Mac: the installer stops with a clear message and installs nothing" {
    remove_tool brew
    rm "$MACHINE/clt"
    GAUDI_REPO_URL="file://$(gaudi_remote)"
    export FAKE_CURL_FAIL=1 GAUDI_REPO_URL

    run bash "$GAUDI_ROOT/install.sh" --yes </dev/null
    assert_failure 1
    assert_output_contains "Could not download the Homebrew installer"
    refute_file_exists "$HOME/.gaudi"
    refute_file_exists "$HOME/.local/bin/gaudi"
    assert_equal "$(machine_snapshot)" ""
}

@test "gaudi-shell's exported variables do not leak into setup" {
    export GAUDI_SHELL="/somewhere/gaudi-shell" GAUDI_SHELL_PROFILE=".zshrc" GAUDI_SHELL_THEME="gaudi"
    mkdir -p "$SANDBOX/project"
    cd "$SANDBOX/project"

    run full_setup
    assert_success
    assert_equal "$(ls -A "$SANDBOX/project")" ""
    assert_file_contains "$HOME/.zshrc" ".local/bin"
    assert_output_contains "[INFO] Shell profile: $HOME/.zshrc"
}

@test "setup works in a bare environment (no TERM, no SHELL, nothing exported)" {
    run env -i HOME="$HOME" PATH="$PATH" MACHINE="$MACHINE" FAKES_DIR="$FAKES_DIR" FAKE_BREW_PREFIX="$FAKE_BREW_PREFIX" \
        FAKE_UNAME="Darwin" GAUDI_BREW_BIN_DIRS="$GAUDI_BREW_BIN_DIRS" GAUDI_TEMPLATES_LOCATION="$GAUDI_TEMPLATES_LOCATION" \
        "$GAUDI_ROOT/setup.sh" --yes --skip-ssh --skip-shell-helpers --skip-templates </dev/null
    assert_success
    assert_output_contains "[OK] Gaudi setup finished"
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
}

@test "a home directory and a templates directory with spaces in their names work" {
    export HOME="$SANDBOX/home of someone"
    mkdir -p "$HOME"
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/my templates"
    standard_templates "$GAUDI_TEMPLATES_LOCATION"

    run full_setup
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
    assert_file_contains "$MACHINE/gem.txt" "tmuxinator"
    assert_file_contains "$MACHINE/hooks.log" "post.bundle-core.extra"
    [[ -L "$HOME/.local/bin/gaudi" ]]
    assert_file_contains "$HOME/.zshrc" "export PATH=\"$HOME/.local/bin:\$PATH\""
}

@test "a Gaudi checkout in a directory with spaces works" {
    COPY="$SANDBOX/my gaudi checkout"
    mkdir -p "$COPY"
    cp -R "$GAUDI_ROOT/bin" "$GAUDI_ROOT/lib" "$GAUDI_ROOT/configs" "$GAUDI_ROOT/setup.sh" "$GAUDI_ROOT/backup.sh" "$COPY/"

    run "$COPY/setup.sh" --yes --skip-ssh --skip-shell-helpers --skip-templates </dev/null
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"

    run "$HOME/.local/bin/gaudi" backup "$SANDBOX/out"
    assert_success
    assert_file_contains "$SANDBOX/out/Brewfile" 'brew "jq"'
}

@test "an empty templates directory is not an error" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/empty-templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"

    run full_setup
    assert_success
    assert_equal "$(machine_snapshot)" ""
}

@test "templates with only configs, or only software, work" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/only-configs"
    standard_templates "$SANDBOX/only-configs"
    rm -rf "$SANDBOX/only-configs/lists" "$SANDBOX/only-configs/hooks"
    run full_setup
    assert_success
    assert_equal "$(machine_snapshot)" ""
    assert_file_contains "$MACHINE/defaults.txt" "ShowPathbar"

    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/only-software"
    standard_templates "$SANDBOX/only-software"
    rm -rf "$SANDBOX/only-software/configs" "$SANDBOX/only-software/hooks"
    run full_setup
    assert_success
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
}

@test "a hook that changes the environment affects the steps after it" {
    printf 'export FAKE_BREW_FAIL="jq"\n' > "$GAUDI_TEMPLATES_LOCATION/hooks/pre.bundle.hooks.sh"

    run full_setup
    assert_failure 1
    refute_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/brew.txt" "example/tap/special"
}

@test "GAUDI_BUNDLE_NO_UPGRADE reaches every brew bundle call of a full run" {
    export GAUDI_BUNDLE_NO_UPGRADE="true"
    run full_setup
    assert_success
    assert_equal "$(calls | grep -c '^brew bundle install .* --no-upgrade$')" "3"
}
