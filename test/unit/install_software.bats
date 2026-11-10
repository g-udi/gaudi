#!/usr/bin/env bats
# lib/install-software.sh: Brewfiles, apt/gem lists and their hooks

load ../helper

setup() {
    gaudi_sandbox darwin
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    export NO_TEMPLATES="$SANDBOX/no-templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
}

# Switch the simulated machine to Debian, keeping the templates location
use_debian() {
    gaudi_sandbox debian
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    export NO_TEMPLATES="$SANDBOX/no-templates"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION"
}

# Load the functions of install-software.sh without running its main flow
# (it returns early when the templates directory is missing), then run code.
software() {
    call eval 'get_os; templates="$GAUDI_TEMPLATES_LOCATION"; GAUDI_TEMPLATES_LOCATION="$NO_TEMPLATES"; source "$SOURCE_LOCATION/lib/install-software.sh" 2>/dev/null; GAUDI_TEMPLATES_LOCATION="$templates"; '"$1"
}

# A hook that records its name in the same log as the fake tools
hook() {
    printf 'printf "hook %s\\n" >> "$MACHINE/calls.log"\n' "$2" | write_file "$GAUDI_TEMPLATES_LOCATION/$1"
}

brewfile() {
    write_file "$GAUDI_TEMPLATES_LOCATION/$1"
}

# --- discovery ---------------------------------------------------------------------

@test "brewfiles finds Brewfile and <name>.Brewfile anywhere in the templates, sorted" {
    printf 'brew "a"\n' | brewfile "lists/core.Brewfile"
    printf 'brew "b"\n' | brewfile "lists/apps.Brewfile"
    printf 'brew "c"\n' | brewfile "Brewfile"
    printf 'brew "d"\n' | brewfile "deep/er/extra.Brewfile"

    run software 'gaudi::brewfiles'
    assert_success
    assert_output_equals "$GAUDI_TEMPLATES_LOCATION/Brewfile
$GAUDI_TEMPLATES_LOCATION/deep/er/extra.Brewfile
$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile
$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
}

@test "brewfiles ignores lock files, backups and directories" {
    printf '{}\n' | brewfile "Brewfile.lock.json"
    printf 'x\n' | brewfile "core.Brewfile.bak"
    printf 'x\n' | brewfile "brewfile"
    mkdir -p "$GAUDI_TEMPLATES_LOCATION/dir.Brewfile"

    run software 'gaudi::brewfiles'
    assert_success
    assert_output_equals ""
}

@test "brewfiles prints nothing without a templates directory" {
    export GAUDI_TEMPLATES_LOCATION="$NO_TEMPLATES"
    run software 'gaudi::brewfiles'
    assert_success
    assert_output_equals ""
}

@test "brewfile_name: Brewfile is default, <name>.Brewfile is <name>" {
    run software 'gaudi::brewfile_name /some/where/Brewfile'
    assert_output_equals "default"
    run software 'gaudi::brewfile_name /some/where/core.Brewfile'
    assert_output_equals "core"
    run software 'gaudi::brewfile_name my.apps.Brewfile'
    assert_output_equals "my.apps"
}

@test "template_files_for_type finds list files in every supported spelling" {
    for name in default.apt.list.sh default.apt-get.sh extra.apt.sh servers.apt-extra.list.sh; do
        printf '# @List: x\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/$name"
    done
    printf '# @List: x\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.gem.list.sh"

    run software 'gaudi::template_files_for_type apt'
    assert_success
    assert_output_contains "default.apt.list.sh"
    assert_output_contains "default.apt-get.sh"
    assert_output_contains "extra.apt.sh"
    assert_output_contains "servers.apt-extra.list.sh"
    refute_output_contains "gem"
}

@test "template_files_for_type never treats a hook as a list" {
    printf 'true\n' | write_file "$GAUDI_TEMPLATES_LOCATION/hooks/pre.apt-docker.hooks.sh"
    printf 'true\n' | write_file "$GAUDI_TEMPLATES_LOCATION/hooks/pre.apt.hooks.sh"

    run software 'gaudi::template_files_for_type apt'
    assert_output_equals ""
}

@test "installer_available_for_type checks the package manager" {
    run software 'gaudi::installer_available_for_type gem'
    assert_success
    run software 'gaudi::installer_available_for_type apt'
    assert_failure
    remove_tool gem
    run software 'gaudi::installer_available_for_type gem'
    assert_failure
    run software 'gaudi::installer_available_for_type anything-else'
    assert_success
}

# --- one Brewfile --------------------------------------------------------------------

@test "install_brewfile does nothing when declined" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    hook "hooks/pre.bundle-core.hooks.sh" "pre-core"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"'
    assert_success
    assert_output_contains "Install this Brewfile? [y/N]"
    refute_called "brew bundle"
    refute_called "hook pre-core"
}

@test "install_brewfile runs pre hooks, the bundle, then post hooks" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    hook "hooks/pre.bundle-core.hooks.sh" "pre-core"
    hook "hooks/post.bundle-core.hooks.sh" "post-core"
    hook "hooks/sub/post.bundle-core.asdf.hooks.sh" "post-core-asdf"
    hook "hooks/sub/pre.bundle-core.rosetta.hooks.sh" "pre-core-rosetta"
    export GAUDI_ASSUME_YES="true"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"'
    assert_success
    assert_equal "$(calls | grep -E '^(hook|brew bundle)')" "hook pre-core
hook pre-core-rosetta
brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile
hook post-core
hook post-core-asdf"
}

@test "install_brewfile never runs hooks that belong to another Brewfile" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    hook "hooks/post.bundle-core-extra.hooks.sh" "core-extra"
    hook "hooks/post.bundle-apps.hooks.sh" "apps"
    hook "hooks/post.bundle.hooks.sh" "global"
    export GAUDI_ASSUME_YES="true"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"'
    assert_success
    refute_called "hook core-extra"
    refute_called "hook apps"
    refute_called "hook global"
}

@test "install_brewfile shows @Name and @Description" {
    printf '# @Name: Core tools\n# @Description: Command-line things\nbrew "jq"\n' | brewfile "lists/core.Brewfile"
    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"'
    assert_output_contains "Brewfile: Core tools ($GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile)"
    assert_output_contains "Command-line things"
}

@test "install_brewfile falls back to the file's name without @Name" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"'
    assert_output_contains "Brewfile: core ("

    printf 'brew "jq"\n' | brewfile "Brewfile"
    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/Brewfile"'
    assert_output_contains "Brewfile: default ("
}

@test "install_brewfile records a failed bundle, keeps what installed, and still runs post hooks" {
    printf 'brew "jq"\nbrew "broken"\nbrew "tree"\n' | brewfile "lists/core.Brewfile"
    hook "hooks/post.bundle-core.hooks.sh" "post-core"
    export GAUDI_ASSUME_YES="true" FAKE_BREW_FAIL="broken"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"; gaudi::report_failures'
    assert_failure 1
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_file_contains "$MACHINE/brew/brew.txt" "tree"
    assert_called "hook post-core"
    assert_output_contains "rerun: brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
}

# --- one list file ---------------------------------------------------------------------

apt_list() {
    write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"
}

install_apt_list() {
    software 'gaudi::install_list_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh" "sudo apt-get install -y" apt; gaudi::report_failures'
}

@test "install_list_file skips a file without @List" {
    use_debian
    printf 'aptList=( "tree" )\n' | apt_list
    export GAUDI_ASSUME_YES="true"

    run install_apt_list
    assert_success
    assert_output_contains "missing # @List metadata"
    refute_called "apt-get"
}

@test "install_list_file skips a file whose array is not defined" {
    use_debian
    printf '# @List: aptList\notherName=( "tree" )\n' | apt_list
    export GAUDI_ASSUME_YES="true"

    run install_apt_list
    assert_success
    assert_output_contains "array not defined: aptList"
    refute_called "apt-get"
}

@test "install_list_file skips an empty list" {
    use_debian
    printf '# @List: aptList\naptList=(\n)\n' | apt_list
    export GAUDI_ASSUME_YES="true"

    run install_apt_list
    assert_success
    assert_output_contains "the list is empty"
    refute_called "apt-get"
}

@test "install_list_file does nothing when the list is declined" {
    use_debian
    printf '# @Name: Servers\n# @Description: Server packages\n# @List: aptList\naptList=( "tree" )\n' | apt_list

    run install_apt_list
    assert_success
    assert_output_contains "Software list: Servers (apt)"
    assert_output_contains "Server packages"
    assert_output_contains "Proceed with this list? [y/N]"
    refute_called "apt-get"
}

@test "install_list_file installs everything when accepted" {
    use_debian
    printf '# @List: aptList\naptList=(\n  "tree::Directory listing"\n  "htop"\n)\n' | apt_list
    export GAUDI_ASSUME_YES="true"

    run install_apt_list
    assert_success
    assert_output_contains "Software list: default.apt.list.sh (apt)"
    assert_file_contains "$MACHINE/apt.txt" "tree"
    assert_file_contains "$MACHINE/apt.txt" "htop"
}

@test "install_list_file can go through the items one by one" {
    use_debian
    printf '# @List: aptList\naptList=( "first" "second" "third" )\n' | apt_list
    interactive

    # proceed: y, install all: n, then first: y, second: n, third: y
    run install_apt_list <<< "ynyny"
    assert_success
    assert_file_contains "$MACHINE/apt.txt" "first"
    refute_file_contains "$MACHINE/apt.txt" "second"
    assert_file_contains "$MACHINE/apt.txt" "third"
}

@test "install_list_file records a list file that fails to load" {
    use_debian
    printf '# @List: aptList\naptList=( "tree" )\nfalse\n' | apt_list
    export GAUDI_ASSUME_YES="true"

    run install_apt_list
    assert_failure 1
    assert_output_contains "list $GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"
    refute_called "apt-get"
}

# --- the whole step ------------------------------------------------------------------

@test "step: a missing templates directory is a warning, not a failure" {
    export GAUDI_TEMPLATES_LOCATION="$NO_TEMPLATES"
    run step lib/install-software.sh
    assert_success
    assert_output_contains "Template directory not found: $NO_TEMPLATES"
}

@test "step: Brewfiles run in sorted order between the global hooks" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    printf 'cask "kitty"\n' | brewfile "lists/apps.Brewfile"
    hook "hooks/pre.bundle.hooks.sh" "pre-global"
    hook "hooks/post.bundle.hooks.sh" "post-global"
    hook "hooks/post.bundle-apps.hooks.sh" "post-apps"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^(hook|brew bundle)')" "hook pre-global
brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile
hook post-apps
brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile
hook post-global"
}

@test "step: declined Brewfiles skip their own hooks but global hooks still run" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    hook "hooks/pre.bundle.hooks.sh" "pre-global"
    hook "hooks/pre.bundle-core.hooks.sh" "pre-core"

    run step lib/install-software.sh
    assert_success
    assert_called "hook pre-global"
    refute_called "hook pre-core"
    refute_called "brew bundle"
}

@test "step: Brewfiles are skipped with a warning when Homebrew is missing" {
    remove_tool brew
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    printf 'cask "kitty"\n' | brewfile "lists/apps.Brewfile"
    hook "hooks/pre.bundle.hooks.sh" "pre-global"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_output_contains "Skipping 2 Brewfile(s): Homebrew is not available"
    refute_called "hook pre-global"
}

@test "step: bundle hooks do not run when there is no Brewfile" {
    hook "hooks/pre.bundle.hooks.sh" "pre-global"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    refute_called "hook pre-global"
}

@test "step: one failing Brewfile does not stop the next one" {
    printf 'brew "broken"\n' | brewfile "lists/a.Brewfile"
    printf 'brew "jq"\n' | brewfile "lists/b.Brewfile"
    export GAUDI_ASSUME_YES="true" FAKE_BREW_FAIL="broken"

    run step lib/install-software.sh
    assert_failure 1
    assert_file_contains "$MACHINE/brew/brew.txt" "jq"
    assert_output_contains "1 step(s) failed"
}

@test "step: old brew/cask/tap/mas/npm/pip/go lists are reported, not installed" {
    for type in brew cask tap mas npm pip go; do
        printf '# @List: oldList\noldList=( "thing" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.$type.list.sh"
    done
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    for type in brew cask tap mas npm pip go; do
        assert_output_contains "Ignoring $GAUDI_TEMPLATES_LOCATION/lists/default.$type.list.sh: '$type' lists moved to Brewfiles"
    done
    refute_called "install"
}

@test "step: apt lists install on Debian with their hooks around them" {
    use_debian
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    printf '# @List: aptList\naptList=( "tree" "htop" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"
    hook "hooks/pre.apt.hooks.sh" "pre-apt"
    hook "hooks/post.apt.hooks.sh" "post-apt"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^(hook|apt-get)')" "hook pre-apt
apt-get install -y tree
apt-get install -y htop
hook post-apt"
}

@test "step: apt lists are ignored on macOS" {
    printf '# @List: aptList\naptList=( "tree" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"
    hook "hooks/pre.apt.hooks.sh" "pre-apt"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    refute_called "apt-get"
    refute_called "hook pre-apt"
}

@test "step: gem lists install on every OS" {
    printf '# @List: gemList\ngemList=( "tmuxinator::Manage tmux sessions" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.gem.list.sh"
    hook "hooks/pre.gem.hooks.sh" "pre-gem"
    hook "hooks/post.gem.hooks.sh" "post-gem"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^(hook|gem install)')" "hook pre-gem
gem install tmuxinator --user-install
hook post-gem"
}

@test "step: a list type whose package manager is missing is skipped with a warning" {
    remove_tool gem
    printf '# @List: gemList\ngemList=( "tmuxinator" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.gem.list.sh"
    hook "hooks/pre.gem.hooks.sh" "pre-gem"
    export GAUDI_ASSUME_YES="true"

    run step lib/install-software.sh
    assert_success
    assert_output_contains "Skipping gem lists: required package manager is not available"
    refute_called "hook pre-gem"
}

@test "step: a failing package in a list is recorded and the rest install" {
    use_debian
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true" FAKE_APT_FAIL="broken"
    printf '# @List: aptList\naptList=( "first" "broken" "third" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"

    run step lib/install-software.sh
    assert_failure 1
    assert_file_contains "$MACHINE/apt.txt" "first"
    assert_file_contains "$MACHINE/apt.txt" "third"
    assert_output_contains "broken (sudo apt-get install -y)"
}

@test "step: a dry run installs nothing and runs no hook" {
    printf 'brew "jq"\n' | brewfile "lists/core.Brewfile"
    printf '# @List: gemList\ngemList=( "tmuxinator" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.gem.list.sh"
    hook "hooks/pre.bundle.hooks.sh" "pre-global"
    hook "hooks/post.bundle-core.hooks.sh" "post-core"
    export GAUDI_ASSUME_YES="true" GAUDI_DRY_RUN="true"

    run step lib/install-software.sh
    assert_success
    assert_output_contains "DRY RUN: brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/core.Brewfile"
    assert_output_contains "DRY RUN: hook $GAUDI_TEMPLATES_LOCATION/hooks/pre.bundle.hooks.sh"
    assert_output_contains "DRY RUN: hook $GAUDI_TEMPLATES_LOCATION/hooks/post.bundle-core.hooks.sh"
    assert_output_contains "DRY RUN: gem_install_or_update install tmuxinator"
    refute_called "brew bundle"
    refute_called "gem install"
    refute_called "hook"
    refute_file_exists "$MACHINE/brew/brew.txt"
}

@test "step: templates default to \$GAUDI/templates" {
    unset GAUDI_TEMPLATES_LOCATION
    export GAUDI="$SANDBOX/gaudi-home" GAUDI_ASSUME_YES="true"
    printf 'brew "jq"\n' | write_file "$GAUDI/templates/Brewfile"

    run step lib/install-software.sh
    assert_success
    assert_called "brew bundle install --file=$GAUDI/templates/Brewfile"
}

# --- picking packages one by one ---------------------------------------------------

@test "pick_brewfile_entries keeps what is accepted, and every line that is not a package" {
    write_file "$SANDBOX/source.Brewfile" <<'BREW'
# @Name: Mixed
cask_args appdir: "/Applications"
tap "example/tap"

# Lightweight JSON processor
brew "jq"
brew "tree"
cask "kitty"
mas "Amphetamine", id: 937984704
BREW
    interactive
    export PICK_SOURCE="$SANDBOX/source.Brewfile" PICK_TARGET="$SANDBOX/picked.Brewfile"

    # jq: y, tree: n, kitty: n, Amphetamine: y
    run software 'gaudi::pick_brewfile_entries "$PICK_SOURCE" "$PICK_TARGET"' <<< "ynny"
    assert_success
    assert_output_contains "jq (brew)"
    assert_output_contains "Description: Lightweight JSON processor"
    assert_output_contains "Install kitty? [y/N]"
    assert_equal "$(cat "$SANDBOX/picked.Brewfile")" '# @Name: Mixed
cask_args appdir: "/Applications"
tap "example/tap"

# Lightweight JSON processor
brew "jq"
mas "Amphetamine", id: 937984704'
}

@test "pick_brewfile_entries shows a description only for the entry right below it" {
    printf '# About jq\nbrew "jq"\nbrew "tree"\n' > "$SANDBOX/source.Brewfile"
    export PICK_SOURCE="$SANDBOX/source.Brewfile" PICK_TARGET="$SANDBOX/picked.Brewfile"
    run software 'gaudi::pick_brewfile_entries "$PICK_SOURCE" "$PICK_TARGET"'
    assert_equal "$(grep -c 'Description:' <<< "$output")" "1"
}

@test "install_brewfile: answering no to 'everything' installs only the picked packages" {
    printf '# @Name: Apps\ntap "example/tap"\ncask "raycast"\ncask "kitty"\ncask "figma"\n' | brewfile "lists/apps.Brewfile"
    hook "hooks/post.bundle-apps.hooks.sh" "post-apps"
    interactive

    # install this Brewfile: y, everything: n, raycast: n, kitty: y, figma: n
    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"' <<< "ynnyn"
    assert_success
    assert_output_contains "Install everything in Apps? [Y/n]"
    assert_equal "$(cat "$MACHINE/brew/cask.txt")" "kitty"
    assert_file_contains "$MACHINE/brew/tap.txt" "example/tap"
    assert_called "hook post-apps"
}

@test "install_brewfile: the temporary picked file is removed afterwards" {
    printf 'cask "kitty"\n' | brewfile "lists/apps.Brewfile"
    interactive
    export TMPDIR="$SANDBOX/tmp"
    mkdir -p "$TMPDIR"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"' <<< "yny"
    assert_success
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
    assert_equal "$(ls -A "$TMPDIR")" ""
}

@test "install_brewfile: Enter at 'everything' installs the whole Brewfile" {
    printf 'cask "raycast"\ncask "kitty"\n' | brewfile "lists/apps.Brewfile"
    interactive

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"' <<< $'y\n'
    assert_success
    assert_called "brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"
    assert_file_contains "$MACHINE/brew/cask.txt" "raycast"
    assert_file_contains "$MACHINE/brew/cask.txt" "kitty"
}

@test "install_brewfile: a failure while picking still names the real Brewfile" {
    printf 'cask "kitty"\n' | brewfile "lists/apps.Brewfile"
    interactive
    export FAKE_BREW_FAIL="kitty"

    run software 'gaudi::install_brewfile "$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"; gaudi::report_failures' <<< "yny"
    assert_failure 1
    assert_output_contains "rerun: brew bundle install --file=$GAUDI_TEMPLATES_LOCATION/lists/apps.Brewfile"
}

# --- Fedora ------------------------------------------------------------------------

@test "step: dnf lists install on Fedora with their hooks around them" {
    gaudi_sandbox fedora
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    printf '# @List: dnfList\ndnfList=( "tree" "htop" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.dnf.list.sh"
    printf '# @List: aptList\naptList=( "debian-only" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.apt.list.sh"
    hook "hooks/pre.dnf.hooks.sh" "pre-dnf"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^(hook|dnf)')" "hook pre-dnf
dnf install -y tree
dnf install -y htop"
    refute_called "debian-only"
}

@test "step: dnf lists are ignored on Debian and macOS" {
    printf '# @List: dnfList\ndnfList=( "tree" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.dnf.list.sh"
    export GAUDI_ASSUME_YES="true"
    run step lib/install-software.sh
    assert_success
    refute_called "dnf"
}

@test "installer_available_for_type knows dnf" {
    run software 'gaudi::installer_available_for_type dnf'
    assert_failure
    gaudi_sandbox fedora
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" NO_TEMPLATES="$SANDBOX/no-templates"
    run software 'gaudi::installer_available_for_type dnf'
    assert_success
}

# --- Arch and openSUSE ---------------------------------------------------------------

@test "step: pacman lists install on Arch only" {
    gaudi_sandbox arch
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    printf '# @List: pacmanList\npacmanList=( "tree" "htop" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.pacman.list.sh"
    printf '# @List: dnfList\ndnfList=( "fedora-only" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.dnf.list.sh"
    hook "hooks/post.pacman.hooks.sh" "post-pacman"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^(hook|pacman)')" "pacman -S --noconfirm --needed tree
pacman -S --noconfirm --needed htop
hook post-pacman"
    refute_called "fedora-only"
}

@test "step: zypper lists install on openSUSE only" {
    gaudi_sandbox opensuse
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_ASSUME_YES="true"
    printf '# @List: zypperList\nzypperList=( "tree" "htop" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.zypper.list.sh"
    printf '# @List: pacmanList\npacmanList=( "arch-only" )\n' | write_file "$GAUDI_TEMPLATES_LOCATION/lists/default.pacman.list.sh"

    run step lib/install-software.sh
    assert_success
    assert_equal "$(calls | grep -E '^zypper')" "zypper --non-interactive install tree
zypper --non-interactive install htop"
    refute_called "arch-only"
}

@test "installer_available_for_type knows pacman and zypper" {
    run software 'gaudi::installer_available_for_type pacman'
    assert_failure
    run software 'gaudi::installer_available_for_type zypper'
    assert_failure
    gaudi_sandbox arch
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" NO_TEMPLATES="$SANDBOX/no-templates"
    run software 'gaudi::installer_available_for_type pacman'
    assert_success
    gaudi_sandbox opensuse
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" NO_TEMPLATES="$SANDBOX/no-templates"
    run software 'gaudi::installer_available_for_type zypper'
    assert_success
}
