#!/usr/bin/env bats
# check.sh (reached through `gaudi check`): validating a templates directory

load ../helper

setup() {
    gaudi_sandbox darwin
    T="$SANDBOX/templates"
    mkdir -p "$T"
}

check() {
    "$GAUDI_ROOT/bin/gaudi" check "$T" "$@"
}

file() {
    write_file "$T/$1"
}

@test "check: good templates pass with nothing to report" {
    standard_templates "$T"
    run check
    assert_success
    assert_output_contains "0 error(s), 0 warning(s)"
    refute_output_contains "error  "
}

@test "check: the directory defaults to the configured templates" {
    standard_templates "$T"
    export GAUDI_TEMPLATES_LOCATION="$T"
    run "$GAUDI_ROOT/bin/gaudi" check
    assert_success
    assert_output_contains "in $T:"
}

@test "check: a missing directory is an error" {
    run "$GAUDI_ROOT/bin/gaudi" check "$SANDBOX/nowhere"
    assert_failure 1
    assert_output_contains "Templates directory not found: $SANDBOX/nowhere"
}

@test "check: --help prints the usage and an unknown option exits 64" {
    run check --help
    assert_success
    assert_output_contains "Usage: gaudi check [templates-dir] [--online]"
    run check --frobnicate
    assert_failure 64
}

@test "check: a Brewfile Homebrew cannot read is an error" {
    printf 'brew "jq"\nINVALID ruby here\n' | file "lists/core.Brewfile"
    run check
    assert_failure 1
    assert_output_contains "lists/core.Brewfile: Homebrew cannot read this Brewfile"
}

@test "check: without Homebrew, odd Brewfile lines are still pointed out" {
    remove_tool brew
    printf 'brew "jq"\nbrw "typo"\n' | file "lists/core.Brewfile"
    run check
    assert_success
    assert_output_contains 'lists/core.Brewfile: line 2 is not a package entry: brw "typo"'
    assert_output_contains "0 error(s), 1 warning(s)"
}

@test "check: comments, blank lines, taps and cask_args are not flagged" {
    printf '# @Name: Apps\n\ncask_args appdir: "/Applications"\ntap "example/tap"\n  cask "kitty"\n' | file "apps.Brewfile"
    run check
    assert_success
    assert_output_contains "0 error(s), 0 warning(s)"
}

@test "check: a mas entry without an id is an error" {
    printf 'mas "Amphetamine"\nmas "PopClip", id: 445189367\n' | file "appstore.Brewfile"
    run check
    assert_failure 1
    assert_output_contains 'line 1: mas "Amphetamine" needs an id'
    refute_output_contains "PopClip"
}

@test "check: a package listed twice, even across Brewfiles, is a warning" {
    printf 'brew "jq"\nbrew "tree"\n' | file "a.Brewfile"
    printf 'brew "jq"\ncask "jq"\n' | file "b.Brewfile"
    run check
    assert_success
    assert_output_contains "brew jq is listed more than once"
    refute_output_contains "tree is listed"
    refute_output_contains "cask jq is listed"
}

@test "check: a list without @List, without its array, or with broken Bash is an error" {
    printf 'aptList=( "tree" )\n' | file "lists/a.apt.list.sh"
    printf '# @List: aptList\nother=( "tree" )\n' | file "lists/b.apt.list.sh"
    printf '# @List: gemList\nif true; then\ngemList=( "x" )\n' | file "lists/c.gem.list.sh"
    run check
    assert_failure 1
    assert_output_contains "lists/a.apt.list.sh: has no '# @List: <array name>' line"
    assert_output_contains "lists/b.apt.list.sh: does not define the array 'aptList'"
    assert_output_contains "lists/c.gem.list.sh: is not valid Bash"
    assert_output_contains "3 error(s)"
}

@test "check: an empty list is a warning" {
    printf '# @List: dnfList\ndnfList=(\n)\n' | file "lists/default.dnf.list.sh"
    run check
    assert_success
    assert_output_contains "lists/default.dnf.list.sh: the list is empty"
}

@test "check: old brew, cask, tap, mas, npm, pip and go lists are errors" {
    for type in brew cask tap mas npm pip go; do
        printf '# @List: x\nx=( "y" )\n' | file "lists/default.$type.list.sh"
    done
    run check
    assert_failure 1
    assert_output_contains "7 error(s)"
    assert_output_contains "lists/default.pip.list.sh: 'pip' lists are no longer installed: move the entries to a Brewfile"
}

@test "check: every hook name Gaudi runs is accepted" {
    printf 'brew "jq"\n' | file "lists/core.Brewfile"
    printf 'brew "jq2"\n' | file "Brewfile"
    for name in pre.bundle post.bundle pre.bundle-core post.bundle-core post.bundle-core.asdf pre.bundle-default pre.apt post.apt pre.apt-docker post.gem pre.dnf post.pacman pre.zypper; do
        printf 'true\n' | file "hooks/$name.hooks.sh"
    done
    run check
    assert_success
    assert_output_contains "0 error(s), 0 warning(s)"
}

@test "check: a hook for a Brewfile that does not exist never runs, and that is an error" {
    printf 'brew "jq"\n' | file "lists/core.Brewfile"
    printf 'true\n' | file "hooks/post.bundle-apps.hooks.sh"
    printf 'true\n' | file "hooks/post.bundle-core-extra.hooks.sh"
    run check
    assert_failure 1
    assert_output_contains "hooks/post.bundle-apps.hooks.sh: never runs: no Brewfile matches its name (have: core )"
    assert_output_contains "hooks/post.bundle-core-extra.hooks.sh: never runs"
}

@test "check: a hook with any other name never runs, and that is an error" {
    for name in post.brew pre.npm post.asdf-languages after.bundle bundle; do
        printf 'true\n' | file "hooks/$name.hooks.sh"
    done
    run check
    assert_failure 1
    assert_output_contains "5 error(s)"
    assert_output_contains "hooks/post.brew.hooks.sh: never runs: the name is not"
}

@test "check: a hook with broken Bash is an error" {
    printf 'if true; then\n' | file "hooks/pre.bundle.hooks.sh"
    run check
    assert_failure 1
    assert_output_contains "hooks/pre.bundle.hooks.sh: is not valid Bash"
}

@test "check: a config with a misspelt or missing .configs. suffix never runs, and that is an error" {
    printf '_info="x"\n_command() { true; }\n' | file "configs/bluetooth.confgis.osx.sh"
    printf '_info="x"\n_command() { true; }\n' | file "configs/nested/activity_monitor.sh"
    printf '_info="x"\n_command() { true; }\n' | file "configs/fine.configs.osx.sh"
    run check
    assert_failure 1
    assert_output_contains "configs/bluetooth.confgis.osx.sh: never runs: configs are named"
    assert_output_contains "configs/nested/activity_monitor.sh: never runs"
    assert_output_contains "2 error(s)"
}

@test "check: a config for an unknown OS is an error" {
    printf '_info="x"\n_command() { true; }\n' | file "configs/a.configs.macos.sh"
    for os in osx debian fedora arch opensuse; do
        printf '_info="x"\n_command() { true; }\n' | file "configs/b.configs.$os.sh"
    done
    run check
    assert_failure 1
    assert_output_contains "configs/a.configs.macos.sh: never runs: 'macos' is not one of: osx debian fedora arch opensuse"
    assert_output_contains "1 error(s)"
}

@test "check: a config without _command is an error; without _info a warning" {
    printf '_info="No command"\n' | file "configs/a.configs.sh"
    printf 'function _command {\n  true\n}\n' | file "configs/b.configs.sh"
    run check
    assert_failure 1
    assert_output_contains "configs/a.configs.sh: does not define _command, so it is skipped"
    assert_output_contains "configs/b.configs.sh: has no _info"
    assert_output_contains "1 error(s), 1 warning(s)"
}

@test "check: helper scripts outside a configs directory are left alone" {
    printf 'echo helper\n' | file "hooks/bundle/asdf-languages.post.sh"
    printf 'export x=( "a" )\n' | file "lists/custom/asdf-plugins.list.sh"
    run check
    assert_success
    assert_output_contains "0 error(s), 0 warning(s)"
}

@test "check: dotfiles.list entries must be paths inside the home directory" {
    printf '# shell\n.zshrc\n.config/kitty\n/etc/hosts\n../outside\n~/.vimrc\n' | file "dotfiles.list"
    run check
    assert_failure 1
    assert_output_contains "dotfiles.list: line 4: '/etc/hosts' must be a path inside the home directory"
    assert_output_contains "line 5"
    assert_output_contains "line 6"
    assert_output_contains "3 error(s)"
}

@test "check --online: missing and disabled packages are errors, deprecated ones warnings" {
    printf 'brew "jq"\nbrew "gone"\nbrew "old"\ncask "dead"\nnpm "eslint"\n' | file "Brewfile"
    export FAKE_BREW_MISSING="gone" FAKE_BREW_DEPRECATED="old" FAKE_BREW_DISABLED="dead"
    run check --online
    assert_failure 1
    assert_output_contains "Brewfile: formula gone was not found in Homebrew"
    assert_output_contains "Brewfile: old is deprecated in Homebrew and will stop installing"
    assert_output_contains "Brewfile: dead is disabled in Homebrew and can no longer be installed"
    assert_output_contains "2 error(s), 1 warning(s)"
    assert_called "brew info --formula jq"
    assert_called "brew info --cask dead"
    refute_called "brew info --formula eslint"
}

@test "check: without --online Homebrew is never asked about individual packages" {
    printf 'brew "gone"\n' | file "Brewfile"
    export FAKE_BREW_MISSING="gone"
    run check
    assert_success
    refute_called "brew info"
}

@test "check --online without Homebrew is skipped with a warning" {
    remove_tool brew
    printf 'brew "jq"\n' | file "Brewfile"
    run check --online
    assert_success
    assert_output_contains "--online needs Homebrew: skipped"
}

@test "check: only reads; it installs nothing and runs no hook or config" {
    standard_templates "$T"
    run check
    assert_success
    assert_equal "$(machine_snapshot)" ""
    refute_file_exists "$MACHINE/hooks.log"
    refute_file_exists "$MACHINE/configs.log"
    refute_called "install"
    assert_cwd_clean
}

@test "check: paths with spaces work" {
    T="$SANDBOX/my templates"
    standard_templates "$T"
    run check
    assert_success
    assert_output_contains "0 error(s), 0 warning(s)"
}

@test "check.sh can be run directly" {
    standard_templates "$T"
    run "$GAUDI_ROOT/check.sh" "$T"
    assert_success
}

@test "check --online: a package from a tap that is not installed here is a warning, not an error" {
    printf 'tap "example/tap"\nbrew "example/tap/special"\nbrew "other/tap/thing"\n' | file "Brewfile"
    mkdir -p "$MACHINE/brew"
    printf 'example/tap\n' > "$MACHINE/brew/tap.txt"
    export FAKE_BREW_MISSING="other/tap/thing"

    run check --online
    assert_success
    assert_output_contains "other/tap/thing cannot be verified: the tap other/tap is not installed on this machine"
    assert_called "brew info --formula example/tap/special"
    refute_called "brew info --formula other/tap/thing"
    assert_output_contains "0 error(s), 1 warning(s)"
}

@test "check --online: a package that was deprecated and then disabled counts as disabled" {
    printf 'cask "qlthing"\n' | file "Brewfile"
    export FAKE_BREW_DISABLED_AFTER_DEPRECATION="qlthing"
    run check --online
    assert_failure 1
    assert_output_contains "qlthing is disabled in Homebrew and can no longer be installed"
    refute_output_contains "deprecated"
}
