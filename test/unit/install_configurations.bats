#!/usr/bin/env bats
# lib/install-configurations.sh: the same step on every operating system

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
}

# config <file> <name>: a config script that records its name when applied
config() {
    printf '_info="Config %s"\n_command() { printf "%s\\n" >> "$MACHINE/configs.log"; }\n' "$2" "$2" \
        | write_file "$GAUDI_TEMPLATES_LOCATION/$1"
}

applied() {
    [[ -f "$MACHINE/configs.log" ]] && cat "$MACHINE/configs.log"
    return 0
}

@test "a missing templates directory is a warning, not a failure" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/no-templates"
    run step lib/install-configurations.sh
    assert_success
    assert_output_contains "Template directory not found"
}

@test "--yes applies OS-specific and shared configs in sorted order, not other OSes" {
    config "configs/b_dock.configs.osx.sh" "dock"
    config "configs/a_shared.configs.sh" "shared"
    config "configs/nested/c_finder.configs.osx.sh" "finder"
    config "configs/d_linux.configs.debian.sh" "linux-only"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" "shared
dock
finder"
}

@test "Debian applies debian and shared configs" {
    gaudi_sandbox debian
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    config "configs/a.configs.osx.sh" "mac-only"
    config "configs/b.configs.debian.sh" "debian"
    config "configs/c.configs.sh" "shared"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" "debian
shared"
}

@test "files that do not follow the naming convention are ignored" {
    config "configs/plain.sh" "plain"
    config "configs/typo.confgis.osx.sh" "typo"
    config "configs/readme.configs.osx.txt" "text"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" ""
}

@test "declining every config finishes the step successfully" {
    config "configs/a.configs.osx.sh" "a"
    config "configs/b.configs.osx.sh" "b"

    run step lib/install-configurations.sh
    assert_success
    assert_output_contains "Install all recommended configs? [y/N]"
    assert_output_contains "Config a [y/N]"
    assert_output_contains "Config b [y/N]"
    assert_output_contains "STEP-DONE"
    assert_equal "$(applied)" ""
}

@test "configs can be picked one by one" {
    config "configs/a.configs.osx.sh" "a"
    config "configs/b.configs.osx.sh" "b"
    config "configs/c.configs.osx.sh" "c"
    interactive

    # install all: n, then a: y, b: n, c: y
    run step lib/install-configurations.sh <<< "nyny"
    assert_success
    assert_equal "$(applied)" "a
c"
}

@test "answering yes to 'install all' applies everything without asking again" {
    config "configs/a.configs.osx.sh" "a"
    config "configs/b.configs.osx.sh" "b"
    interactive

    run step lib/install-configurations.sh <<< "y"
    assert_success
    assert_equal "$(applied)" "a
b"
    refute_output_contains "Config a [y/N]"
}

@test "a config without _command is skipped with a warning" {
    printf '_info="No command here"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    config "configs/b.configs.osx.sh" "b"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_output_contains "a.configs.osx.sh: _command function is missing"
    assert_equal "$(applied)" "b"
}

@test "a config never inherits _command or _info from the previous one" {
    config "configs/a.configs.osx.sh" "a"
    printf '# defines nothing\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/b.configs.osx.sh"
    printf '_command() { printf "c\\n" >> "$MACHINE/configs.log"; }\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/c.configs.osx.sh"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" "a
c"
    assert_output_contains "b.configs.osx.sh: _command function is missing"
    # c has no _info, so its file name is shown, not "Config a"
    assert_output_contains "c.configs.osx.sh"
}

@test "a failing config is recorded and the rest still apply" {
    printf '_info="Broken config"\n_command() { return 3; }\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    config "configs/b.configs.osx.sh" "b"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_failure 1
    assert_equal "$(applied)" "b"
    assert_output_contains "1 step(s) failed"
    assert_output_contains "config Broken config"
}

@test "a config file that fails to load is recorded and the rest still apply" {
    printf 'false\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    config "configs/b.configs.osx.sh" "b"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_failure 1
    assert_equal "$(applied)" "b"
    assert_output_contains "config $GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
}

@test "a config whose command fails in the middle of _command is recorded" {
    printf '_info="Half config"\n_command() {\n    false\n    printf "half\\n" >> "$MACHINE/configs.log"\n}\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    config "configs/b.configs.osx.sh" "b"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_failure 1
    assert_equal "$(applied)" "half
b"
    assert_output_contains "1 step(s) failed"
    assert_output_contains "  - config Half config: "
    assert_output_contains " failed with status 1"
}

@test "a config that calls exit, while loading or in _command, is recorded and the rest still apply" {
    printf 'exit 0\n_command() { :; }\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    printf '_info="Leaving config"\n_command() { exit 3; }\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/b.configs.osx.sh"
    config "configs/c.configs.osx.sh" "c"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_failure 1
    assert_equal "$(applied)" "c"
    assert_output_contains "STEP-DONE"
    assert_output_contains "2 step(s) failed"
    assert_output_contains "  - config $GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh: it called exit: use return to stop early"
    assert_output_contains "  - config Leaving config: it called exit: use return to stop early"
}

@test "a config that handles its own failures is not recorded" {
    printf '_info="Careful config"\n_command() {\n    false || true\n    if ! command_exists no-such-tool; then printf "careful\\n" >> "$MACHINE/configs.log"; fi\n}\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" "careful"
}

@test "a dry run names the configs without applying them" {
    config "configs/a.configs.osx.sh" "a"
    export GAUDI_ASSUME_YES="true" GAUDI_DRY_RUN="true"

    run step lib/install-configurations.sh
    assert_success
    assert_output_contains "DRY RUN: config $GAUDI_TEMPLATES_LOCATION/configs/a.configs.osx.sh"
    assert_equal "$(applied)" ""
}

@test "configs can call the machine's tools (defaults)" {
    write_file "$GAUDI_TEMPLATES_LOCATION/configs/finder.configs.osx.sh" <<'EOF'
_info="Show Finder path bar"
_command() {
    defaults write com.apple.finder ShowPathbar -bool true
}
EOF
    export GAUDI_ASSUME_YES="true"

    run step lib/install-configurations.sh
    assert_success
    assert_file_contains "$MACHINE/defaults.txt" "write com.apple.finder ShowPathbar -bool true"
}

@test "no operating system has a configure.sh of its own: setup sources the one step" {
    [[ -z "$(find "$GAUDI_ROOT/lib" -name configure.sh)" ]]
    grep -q 'source_if_exists "$SOURCE_LOCATION/lib/install-configurations.sh"' "$GAUDI_ROOT/setup.sh"
}

@test "Fedora applies fedora and shared configs" {
    gaudi_sandbox fedora
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    config "configs/a.configs.osx.sh" "mac-only"
    config "configs/b.configs.fedora.sh" "fedora"
    config "configs/c.configs.sh" "shared"

    run step lib/install-configurations.sh
    assert_success
    assert_equal "$(applied)" "fedora
shared"
}

@test "Arch and openSUSE apply their own and shared configs" {
    for os in arch opensuse; do
        gaudi_sandbox "$os"
        export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates-$os" GAUDI_ASSUME_YES="true"
        mkdir -p "$GAUDI_TEMPLATES_LOCATION"
        config "configs/a.configs.fedora.sh" "fedora-only"
        config "configs/b.configs.$os.sh" "$os"
        config "configs/c.configs.sh" "shared"

        run step lib/install-configurations.sh
        assert_success
        assert_equal "$(applied)" "$os
shared"
    done
}

@test "a dry run does not run anything a config has outside _command" {
    printf 'touch "$MACHINE/config-code-ran"\n_info="Careful config"\n_command()\n{\n    touch "$MACHINE/command-ran"\n}\n' \
        | write_file "$GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
    printf '_info="No command here"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/configs/b.configs.sh"
    export GAUDI_ASSUME_YES="true" GAUDI_DRY_RUN="true"

    run step lib/install-configurations.sh
    assert_success
    assert_output_contains "Careful config"
    assert_output_contains "DRY RUN: config $GAUDI_TEMPLATES_LOCATION/configs/a.configs.sh"
    assert_output_contains "Skipping $GAUDI_TEMPLATES_LOCATION/configs/b.configs.sh: _command function is missing"
    refute_file_exists "$MACHINE/config-code-ran"
    refute_file_exists "$MACHINE/command-ran"
}
