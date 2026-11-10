#!/usr/bin/env bats
# bin/helpers.sh: everything except the prompt functions (see prompts.bats)

load ../helper

setup() {
    gaudi_sandbox darwin
}

stdout_of() { "$@" 2>/dev/null; }
stderr_of() { { "$@" >/dev/null; } 2>&1; }

shell_type() {
    call eval 'get_os; get_shell_type; printf "%s|%s" "$GAUDI_SETUP_SHELL" "$GAUDI_SETUP_PROFILE"'
}

detected_os() {
    call eval 'get_os; printf "%s" "$OS"'
}

# --- gaudi::find_command / command_exists ---------------------------------------

@test "find_command prints the path of a command on PATH" {
    run call gaudi::find_command brew
    assert_success
    assert_output_equals "$FAKEBIN/brew"
}

@test "find_command falls back to the Homebrew bin directories" {
    remove_tool brew
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    cp "$FAKES_DIR/brew" "$FAKE_BREW_PREFIX/bin/brew"

    run call gaudi::find_command brew
    assert_success
    assert_output_equals "$FAKE_BREW_PREFIX/bin/brew"
}

@test "find_command prefers PATH over the fallback directories" {
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    cp "$FAKES_DIR/brew" "$FAKE_BREW_PREFIX/bin/brew"

    run call gaudi::find_command brew
    assert_output_equals "$FAKEBIN/brew"
}

@test "find_command searches every directory in GAUDI_BREW_BIN_DIRS" {
    remove_tool brew
    mkdir -p "$SANDBOX/second/bin"
    cp "$FAKES_DIR/brew" "$SANDBOX/second/bin/brew"
    export GAUDI_BREW_BIN_DIRS="$SANDBOX/first/bin:$SANDBOX/second/bin"

    run call gaudi::find_command brew
    assert_output_equals "$SANDBOX/second/bin/brew"
}

@test "find_command fails for a missing command and prints nothing" {
    run call gaudi::find_command definitely-not-installed
    assert_failure
    assert_output_equals ""
}

@test "find_command with an empty GAUDI_BREW_BIN_DIRS only looks at PATH" {
    remove_tool brew
    export GAUDI_BREW_BIN_DIRS=""

    run call gaudi::find_command brew
    assert_failure
}

@test "find_command ignores a fallback file that is not executable" {
    remove_tool brew
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    printf 'not executable\n' > "$FAKE_BREW_PREFIX/bin/brew"

    run call gaudi::find_command brew
    assert_failure
}

@test "find_command leaves IFS untouched" {
    run call eval 'gaudi::find_command definitely-not-installed || true; gaudi::find_command brew >/dev/null; printf "[%s]" "$IFS"'
    assert_output_equals "$(printf '[ \t\n]')"
}

@test "command_exists is true for an installed command" {
    run call gaudi::command_exists brew
    assert_success
    assert_output_equals ""
}

@test "command_exists is false for a missing command" {
    run call gaudi::command_exists definitely-not-installed
    assert_failure
}

@test "command_exists (legacy name) behaves like gaudi::command_exists" {
    run call command_exists brew
    assert_success
    run call command_exists definitely-not-installed
    assert_failure
}

@test "interactive is false when stdin is not a terminal" {
    run call gaudi::interactive </dev/null
    assert_failure
}

# --- logging ------------------------------------------------------------------------

@test "log prints an INFO line on stdout" {
    run stdout_of call gaudi::log "hello world"
    assert_output_equals "[INFO] hello world"
}

@test "success prints an OK line on stdout" {
    run stdout_of call gaudi::success "done"
    assert_output_equals "[OK] done"
}

@test "warn prints a WARN line on stderr only" {
    run stdout_of call gaudi::warn "careful"
    assert_output_equals ""
    run stderr_of call gaudi::warn "careful"
    assert_output_equals "[WARN] careful"
}

@test "error prints an ERROR line on stderr only" {
    run stdout_of call gaudi::error "broken"
    assert_output_equals ""
    run stderr_of call gaudi::error "broken"
    assert_output_equals "[ERROR] broken"
}

@test "_echo interprets escape sequences without a trailing newline" {
    run call _echo 'a\tb'
    assert_output_equals "$(printf 'a\tb')"
}

# --- failure tracking -------------------------------------------------------------

@test "report_failures succeeds silently when nothing failed" {
    run call gaudi::report_failures
    assert_success
    assert_output_equals ""
}

@test "record_failure reports the failure immediately" {
    run call gaudi::record_failure "jq (brew install)"
    assert_success
    assert_output_contains "[ERROR] Failed: jq (brew install)"
}

@test "report_failures lists every recorded failure and returns 1" {
    run call eval 'gaudi::record_failure "first thing"; gaudi::record_failure "second thing"; gaudi::report_failures'
    assert_failure 1
    assert_output_contains "2 step(s) failed:"
    assert_output_contains "  - first thing"
    assert_output_contains "  - second thing"
}

# --- get_os / supported_os ----------------------------------------------------------

@test "get_os: Darwin is osx" {
    run detected_os
    assert_output_equals "osx"
}

@test "get_os: Linux with apt-get is debian" {
    gaudi_sandbox debian
    run detected_os
    assert_output_equals "debian"
}

@test "get_os: Linux with dnf is fedora" {
    gaudi_sandbox fedora
    run detected_os
    assert_output_equals "fedora"
}

@test "get_os: Linux with yum is centos" {
    gaudi_sandbox debian
    remove_tool apt-get apt-mark
    add_tool yum
    run detected_os
    assert_output_equals "centos"
}

@test "get_os: Linux with zypper is opensuse" {
    gaudi_sandbox debian
    remove_tool apt-get apt-mark
    add_tool zypper
    run detected_os
    assert_output_equals "opensuse"
}

@test "get_os: Linux without a known package manager is linux" {
    gaudi_sandbox debian
    remove_tool apt-get apt-mark
    run detected_os
    assert_output_equals "linux"
}

@test "get_os: any other kernel is unknown" {
    export FAKE_UNAME="FreeBSD"
    run detected_os
    assert_output_equals "unknown"
}

@test "get_os: a missing uname is unknown, not a crash" {
    remove_tool uname
    run detected_os
    assert_success
    assert_output_equals "unknown"
}

@test "get_os exports OS to child processes" {
    run call eval 'get_os; bash -c "printf %s \"\$OS\""'
    assert_output_equals "osx"
}

@test "supported_os accepts osx, debian and fedora only" {
    run call eval 'OS=fedora; gaudi::supported_os'
    assert_success
    run call eval 'OS=osx; gaudi::supported_os'
    assert_success
    run call eval 'OS=debian; gaudi::supported_os'
    assert_success
    for os in centos opensuse linux unknown ""; do
        OS_UNDER_TEST="$os" run call eval 'OS="$OS_UNDER_TEST"; gaudi::supported_os'
        assert_failure
    done
}

# --- get_shell_type -------------------------------------------------------------------

@test "shell: zsh uses ~/.zshrc" {
    export SHELL="/bin/zsh"
    run shell_type
    assert_output_equals "zsh|$HOME/.zshrc"
}

@test "shell: bash on macOS uses ~/.bash_profile" {
    export SHELL="/bin/bash"
    run shell_type
    assert_output_equals "bash|$HOME/.bash_profile"
}

@test "shell: bash on Linux uses ~/.bashrc" {
    gaudi_sandbox debian
    export SHELL="/bin/bash"
    run shell_type
    assert_output_equals "bash|$HOME/.bashrc"
}

@test "shell: fish uses ~/.config/fish/config.fish" {
    export SHELL="/usr/local/bin/fish"
    run shell_type
    assert_output_equals "fish|$HOME/.config/fish/config.fish"
}

@test "shell: sh, dash and ksh use ~/.profile" {
    for shell in sh dash ksh; do
        export SHELL="/bin/$shell"
        run shell_type
        assert_output_equals "$shell|$HOME/.profile"
    done
}

@test "shell: an unknown shell keeps its name and uses ~/.profile" {
    export SHELL="/opt/bin/nu"
    run shell_type
    assert_output_equals "nu|$HOME/.profile"
}

@test "shell: GAUDI_TARGET_SHELL wins over SHELL" {
    export SHELL="/bin/zsh" GAUDI_TARGET_SHELL="fish"
    run shell_type
    assert_output_equals "fish|$HOME/.config/fish/config.fish"
}

@test "shell: with an empty SHELL the running shell is used" {
    export SHELL=""
    run shell_type
    assert_output_equals "bash|$HOME/.bash_profile"
}

@test "shell: an absolute GAUDI_SETUP_PROFILE is used as is" {
    export GAUDI_SETUP_PROFILE="$SANDBOX/custom/profile"
    run shell_type
    assert_output_equals "zsh|$SANDBOX/custom/profile"
}

@test "shell: a relative GAUDI_SETUP_PROFILE is placed under HOME, never the current directory" {
    export GAUDI_SETUP_PROFILE=".myprofile"
    run shell_type
    assert_output_equals "zsh|$HOME/.myprofile"
}

@test "shell: gaudi-shell's GAUDI_SHELL and GAUDI_SHELL_PROFILE are ignored" {
    export GAUDI_SHELL="/somewhere/gaudi-shell" GAUDI_SHELL_PROFILE=".zshrc" SHELL="/bin/bash"
    run shell_type
    assert_output_equals "bash|$HOME/.bash_profile"
}

@test "shell: the result is exported to child processes" {
    run call eval 'get_os; get_shell_type; bash -c "printf %s \"\$GAUDI_SETUP_SHELL:\$GAUDI_SETUP_PROFILE\""'
    assert_output_equals "zsh:$HOME/.zshrc"
}

# --- append_once --------------------------------------------------------------------

@test "append_once creates the file and its directories" {
    run call gaudi::append_once "$HOME/deep/nested/profile" "export A=1"
    assert_success
    assert_file_contains "$HOME/deep/nested/profile" "export A=1"
}

@test "append_once does not add the same line twice" {
    call gaudi::append_once "$HOME/profile" "export A=1"
    call gaudi::append_once "$HOME/profile" "export A=1"
    assert_equal "$(count_in_file "$HOME/profile" "export A=1")" "1"
}

@test "append_once keeps existing content and adds different lines" {
    printf 'existing line\n' > "$HOME/profile"
    call gaudi::append_once "$HOME/profile" "export A=1"
    call gaudi::append_once "$HOME/profile" "export B=2"
    assert_file_contains "$HOME/profile" "existing line"
    assert_file_contains "$HOME/profile" "export A=1"
    assert_file_contains "$HOME/profile" "export B=2"
}

@test "append_once matches whole lines, not substrings" {
    printf 'export A=10\n' > "$HOME/profile"
    call gaudi::append_once "$HOME/profile" "export A=1"
    assert_equal "$(grep -c '^export A=1$' "$HOME/profile")" "1"
}

# --- CLI installation -----------------------------------------------------------------

@test "user_bin_dir defaults to ~/.local/bin" {
    run call gaudi::user_bin_dir
    assert_output_equals "$HOME/.local/bin"
}

@test "user_bin_dir honours GAUDI_BIN_DIR" {
    export GAUDI_BIN_DIR="$SANDBOX/bin"
    run call gaudi::user_bin_dir
    assert_output_equals "$SANDBOX/bin"
}

@test "shell_path_line: POSIX shells export PATH" {
    run call eval 'GAUDI_SETUP_SHELL=zsh; gaudi::shell_path_line /x/bin'
    assert_output_equals 'export PATH="/x/bin:$PATH"'
}

@test "shell_path_line: fish uses set -gx" {
    run call eval 'GAUDI_SETUP_SHELL=fish; gaudi::shell_path_line /x/bin'
    assert_output_equals 'contains -- "/x/bin" $PATH; or set -gx PATH "/x/bin" $PATH'
}

@test "install_cli links the CLI and adds the bin directory to the profile" {
    run call eval 'get_os; get_shell_type; gaudi::install_cli'
    assert_success
    [[ -L "$HOME/.local/bin/gaudi" ]]
    assert_equal "$(readlink "$HOME/.local/bin/gaudi")" "$GAUDI_ROOT/bin/gaudi"
    assert_file_contains "$HOME/.zshrc" "export PATH=\"$HOME/.local/bin:\$PATH\""
    assert_output_contains "Installed gaudi CLI at $HOME/.local/bin/gaudi"
    assert_cwd_clean
}

@test "install_cli leaves the profile alone when the bin directory is already on PATH" {
    export PATH="$PATH:$HOME/.local/bin"
    run call eval 'get_os; get_shell_type; gaudi::install_cli'
    assert_success
    refute_file_exists "$HOME/.zshrc"
    refute_output_contains "was added to"
}

@test "install_cli is idempotent" {
    call eval 'get_os; get_shell_type; gaudi::install_cli' >/dev/null 2>&1
    call eval 'get_os; get_shell_type; gaudi::install_cli' >/dev/null 2>&1
    assert_equal "$(count_in_file "$HOME/.zshrc" ".local/bin")" "1"
    [[ -L "$HOME/.local/bin/gaudi" ]]
}

@test "install_cli installs into GAUDI_BIN_DIR and writes fish syntax for fish" {
    export GAUDI_BIN_DIR="$SANDBOX/tools" GAUDI_TARGET_SHELL="fish"
    run call eval 'get_os; get_shell_type; gaudi::install_cli'
    assert_success
    [[ -L "$SANDBOX/tools/gaudi" ]]
    assert_file_contains "$HOME/.config/fish/config.fish" "set -gx PATH \"$SANDBOX/tools\""
}

# --- Homebrew activation ---------------------------------------------------------------

@test "brew_bin finds brew on PATH" {
    run call gaudi::brew_bin
    assert_output_equals "$FAKEBIN/brew"
}

@test "brew_bin fails when Homebrew is not installed" {
    remove_tool brew
    run call gaudi::brew_bin
    assert_failure
}

@test "activate_brew loads brew into the shell and persists it in the profile" {
    remove_tool brew
    mkdir -p "$FAKE_BREW_PREFIX/bin"
    cp "$FAKES_DIR/brew" "$FAKE_BREW_PREFIX/bin/brew"

    run call eval 'get_os; get_shell_type; gaudi::activate_brew; printf "%s\n" "$HOMEBREW_PREFIX"; type -P brew'
    assert_success
    assert_output_contains "$FAKE_BREW_PREFIX"
    assert_output_contains "$FAKE_BREW_PREFIX/bin/brew"
    assert_file_contains "$HOME/.zshrc" "eval \"\$($FAKE_BREW_PREFIX/bin/brew shellenv)\""
}

@test "activate_brew writes fish syntax for fish" {
    export GAUDI_TARGET_SHELL="fish"
    run call eval 'get_os; get_shell_type; gaudi::activate_brew'
    assert_success
    assert_file_contains "$HOME/.config/fish/config.fish" "$FAKEBIN/brew shellenv fish | source"
}

@test "activate_brew does not duplicate the profile line" {
    call eval 'get_os; get_shell_type; gaudi::activate_brew'
    call eval 'get_os; get_shell_type; gaudi::activate_brew'
    assert_equal "$(count_in_file "$HOME/.zshrc" "brew shellenv")" "1"
}

@test "activate_brew fails when Homebrew is not installed" {
    remove_tool brew
    run call eval 'get_os; get_shell_type; gaudi::activate_brew'
    assert_failure
    refute_file_exists "$HOME/.zshrc"
}

# --- templates plumbing ------------------------------------------------------------------

@test "metadata_value reads a metadata comment" {
    write_file "$SANDBOX/list.sh" <<'EOF'
# @Name: Core tools
# @Description: Command-line tools and libraries
# @List: brewList
EOF
    run call gaudi::metadata_value "$SANDBOX/list.sh" "@Name"
    assert_output_equals "Core tools"
    run call gaudi::metadata_value "$SANDBOX/list.sh" "@Description"
    assert_output_equals "Command-line tools and libraries"
    run call gaudi::metadata_value "$SANDBOX/list.sh" "@List"
    assert_output_equals "brewList"
}

@test "metadata_value is empty for a missing key" {
    printf '# @Name: X\n' > "$SANDBOX/list.sh"
    run call gaudi::metadata_value "$SANDBOX/list.sh" "@Description"
    assert_success
    assert_output_equals ""
}

@test "metadata_value uses the first occurrence only" {
    printf '# @Name: First\n# @Name: Second\n' > "$SANDBOX/list.sh"
    run call gaudi::metadata_value "$SANDBOX/list.sh" "@Name"
    assert_output_equals "First"
}

@test "source_if_exists sources an existing file" {
    printf 'printf "sourced-ok"\n' > "$SANDBOX/step.sh"
    run call gaudi::source_if_exists "$SANDBOX/step.sh"
    assert_success
    assert_output_equals "sourced-ok"
}

@test "source_if_exists warns about a missing file and carries on" {
    run call gaudi::source_if_exists "$SANDBOX/missing.sh"
    assert_success
    assert_output_contains "[WARN] Skipping missing step: $SANDBOX/missing.sh"
}

@test "run_hooks_matching sources matching hooks in sorted order" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    printf 'printf "hook-b\\n"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/z/pre.thing.hooks.sh"
    printf 'printf "hook-a\\n"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/a/pre.thing-extra.hooks.sh"
    printf 'printf "other\\n"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/post.thing.hooks.sh"

    run stdout_of call gaudi::run_hooks_matching "pre.thing*.hooks.sh"
    assert_success
    assert_output_contains "hook-a"
    assert_output_contains "hook-b"
    refute_output_contains "other"
    [[ "$output" == *hook-a*hook-b* ]]
}

@test "run_hooks_matching can use Gaudi's functions inside hooks" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    printf 'command_exists brew && gaudi::success "hook saw brew"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/pre.x.hooks.sh"

    run call gaudi::run_hooks_matching "pre.x.hooks.sh"
    assert_output_contains "[OK] hook saw brew"
}

@test "run_hooks_matching records a failing hook and still runs the next one" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates"
    printf 'false\n' | write_file "$GAUDI_TEMPLATES_LOCATION/pre.x.1.hooks.sh"
    printf 'printf "second-ran\\n"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/pre.x.2.hooks.sh"

    run call eval 'gaudi::run_hooks_matching "pre.x*.hooks.sh"; gaudi::report_failures'
    assert_failure 1
    assert_output_contains "second-ran"
    assert_output_contains "1 step(s) failed"
    assert_output_contains "hook $GAUDI_TEMPLATES_LOCATION/pre.x.1.hooks.sh"
}

@test "run_hooks_matching only names hooks in a dry run" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/templates" GAUDI_DRY_RUN="true"
    printf 'printf "must-not-run\\n"\n' | write_file "$GAUDI_TEMPLATES_LOCATION/pre.x.hooks.sh"

    run call gaudi::run_hooks_matching "pre.x.hooks.sh"
    assert_success
    assert_output_equals "DRY RUN: hook $GAUDI_TEMPLATES_LOCATION/pre.x.hooks.sh"
}

@test "run_hooks_matching does nothing without a templates directory" {
    export GAUDI_TEMPLATES_LOCATION="$SANDBOX/no-such-dir"
    run call gaudi::run_hooks_matching "pre.x.hooks.sh"
    assert_success
    assert_output_equals ""
}

# --- remote installer scripts --------------------------------------------------------------

@test "run_remote_script downloads the script and runs it with its arguments" {
    run call gaudi::run_remote_script sh "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "" --unattended
    assert_success
    assert_called "curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    assert_called "oh-my-zsh-installer --unattended"
    assert_file_exists "$HOME/.oh-my-zsh"
}

@test "run_remote_script fails when the download fails instead of running nothing" {
    export FAKE_CURL_FAIL=1
    run call gaudi::run_remote_script sh "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    assert_failure
    assert_output_contains "Could not download https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    refute_file_exists "$HOME/.oh-my-zsh"
}

@test "run_remote_script returns the installer's own failure" {
    export FAKE_HOMEBREW_INSTALL_FAIL=1
    run call gaudi::run_remote_script /bin/bash "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_failure
}

# --- sourcing template files safely -----------------------------------------------------

@test "source_guarded returns the status of the file's last command" {
    printf 'true\n' > "$SANDBOX/good.sh"
    printf 'false\n' > "$SANDBOX/bad.sh"
    run call gaudi::source_guarded "$SANDBOX/good.sh"
    assert_success
    run call gaudi::source_guarded "$SANDBOX/bad.sh"
    assert_failure 1
}

@test "source_guarded does not let a failing command end the run" {
    printf 'false\nprintf "after-the-failure\\n"\n' > "$SANDBOX/hook.sh"
    export GUARDED_FILE="$SANDBOX/hook.sh"
    run call eval 'gaudi::source_guarded "$GUARDED_FILE" || true; printf "run-continues\n"'
    assert_success
    assert_output_contains "after-the-failure"
    assert_output_contains "run-continues"
}

@test "source_guarded honours an early return and its status" {
    printf 'return 3\nprintf "not-reached\\n"\n' > "$SANDBOX/hook.sh"
    run call gaudi::source_guarded "$SANDBOX/hook.sh"
    assert_failure 3
    refute_output_contains "not-reached"
}

@test "source_guarded keeps what the file defines" {
    printf 'FROM_FILE="kept"\nfrom_file() { printf "function-kept"; }\n' > "$SANDBOX/defs.sh"
    export GUARDED_FILE="$SANDBOX/defs.sh"
    run call eval 'gaudi::source_guarded "$GUARDED_FILE"; printf "%s " "$FROM_FILE"; from_file'
    assert_success
    assert_output_equals "kept function-kept"
}

@test "source_guarded switches exit-on-error back on afterwards" {
    printf 'false\n' > "$SANDBOX/bad.sh"
    export GUARDED_FILE="$SANDBOX/bad.sh"
    run call eval 'gaudi::source_guarded "$GUARDED_FILE" || true; false; printf "must-not-print\n"'
    assert_failure
    refute_output_contains "must-not-print"
}

@test "source_guarded leaves exit-on-error off when it was off" {
    printf 'true\n' > "$SANDBOX/good.sh"
    export GUARDED_FILE="$SANDBOX/good.sh"
    run call eval 'set +e; gaudi::source_guarded "$GUARDED_FILE"; false; printf "still-running\n"'
    assert_success
    assert_output_contains "still-running"
}

# --- running as root ------------------------------------------------------------------------

@test "is_root follows the user id" {
    run call gaudi::is_root
    assert_failure
    export FAKE_UID=0
    run call gaudi::is_root
    assert_success
}

@test "sudo uses the real sudo when it is installed" {
    gaudi_sandbox debian
    run call sudo apt-get update
    assert_success
    assert_called "sudo apt-get update"
}

@test "sudo runs the command directly for root on a machine without sudo" {
    gaudi_sandbox debian
    remove_tool sudo
    export FAKE_UID=0
    run call sudo apt-get install -y tree
    assert_success
    refute_called "sudo"
    assert_file_contains "$MACHINE/apt.txt" "tree"
}

@test "sudo explains what is needed when there is neither sudo nor root" {
    gaudi_sandbox debian
    remove_tool sudo
    run call sudo apt-get install -y tree
    assert_failure 1
    assert_output_contains "This step needs root: install sudo or run Gaudi as root"
    refute_called "apt-get"
}
